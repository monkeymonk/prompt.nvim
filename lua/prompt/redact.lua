-- Masks obvious secrets (API keys, tokens, private keys) out of a prompt
-- buffer before it is written back to the AI tool. Wired to `BufWritePre` on
-- session buffers by `init.setup_redact()`, so it runs both on the explicit
-- `<C-CR>`/`:PromptReturn` path and on a plain `:w`/`:wq`/`ZZ`.
--
-- Best-effort pattern matching, not a security boundary: it catches
-- well-known token shapes and `key = value` / `key: value` assignments whose
-- key name looks secret-ish. It cannot catch a secret with no recognizable
-- shape. Redaction happens in the visible buffer (not silently in flight),
-- so what got masked is always right there to review or undo.
local M = {}

local MASK = "[REDACTED]"

-- {name, pattern, min_len} — `pattern` must match the whole secret in one
-- `string.gsub`; `min_len` guards against matching just a bare prefix.
M.token_patterns = {
  { name = "aws_access_key", pattern = "AKIA" .. string.rep("[%u%d]", 16) },
  { name = "google_api_key", pattern = "AIza" .. string.rep("[%w%-_]", 35) },
  { name = "github_token", pattern = "gh[pousr]_[%w]+", min_len = 40 },
  { name = "github_fine_pat", pattern = "github_pat_[%w_]+", min_len = 30 },
  { name = "slack_token", pattern = "xox[baprs]%-[%w%-]+", min_len = 20 },
  { name = "stripe_secret_key", pattern = "[rs]k_live_[%w]+", min_len = 20 },
  { name = "openai_or_anthropic_key", pattern = "sk%-[%w%-]+", min_len = 20 },
  { name = "jwt", pattern = "eyJ[%w%-_]+%.eyJ?[%w%-_]+%.[%w%-_]+" },
}

-- Key names that make a `key = value` / `key: value` line a secret
-- assignment. Matched case-insensitively, at an identifier boundary (so
-- `db_password` and `STRIPE_SECRET_KEY` match but `primary_key` and
-- `tokenizer` do not — see `redact_assignments`).
M.assignment_hints = {
  "secret",
  "password",
  "passwd",
  "token",
  "apikey",
  "api_key",
  "api-key",
  "accesskey",
  "access_key",
  "access-key",
  "authorization",
  "auth_token",
  "auth-token",
  "private_key",
  "client_secret",
}

-- true at start/end of line or beside a non-alphanumeric char (so `_`/`-`
-- count as boundaries: `DB_PASSWORD` matches, but `mypasswordfoo` does not).
local function is_boundary(ch)
  return ch == nil or ch == "" or not ch:match("%w")
end

-- Redact well-known token *shapes* anywhere on the line.
local function redact_tokens(line)
  local count = 0
  for _, p in ipairs(M.token_patterns) do
    line = line:gsub(p.pattern, function(match)
      if p.min_len and #match < p.min_len then
        return match
      end
      count = count + 1
      return MASK
    end)
  end
  return line, count
end

-- Redact the value half of `key = value` / `key: value` assignments whose
-- key looks secret-ish. The key must end at the hint (a lowercase letter
-- right after it, as in `tokenizer` or `authorized`, disqualifies the
-- match); an optional `_`/`-` continuation (`secret_key`) is allowed before
-- the separator.
local function redact_assignments(line)
  local low = line:lower()
  local out, count, pos = {}, 0, 1

  while true do
    local hit_start, hit_end
    for _, hint in ipairs(M.assignment_hints) do
      local s, e = low:find(hint, pos, true)
      if s and (not hit_start or s < hit_start) then
        hit_start, hit_end = s, e
      end
    end
    if not hit_start then
      table.insert(out, line:sub(pos))
      break
    end

    local before = low:sub(hit_start - 1, hit_start - 1)
    local after = low:sub(hit_end + 1, hit_end + 1)
    local sep_s, sep_e, quote =
      low:find("^[_%-]?[%w_%-]*%s*[:=]%s*(['\"]?)", hit_end + 1)

    if not is_boundary(before) or after:match("%l") or not sep_s then
      table.insert(out, line:sub(pos, hit_start))
      pos = hit_start + 1
    else
      local value_start = sep_e + 1
      local value_end
      if quote ~= "" then
        local q_end = low:find(quote, value_start, true)
        value_end = q_end and (q_end - 1) or #low
      else
        value_end = (low:find("[%s,;]", value_start) or (#low + 1)) - 1
      end

      if value_end < value_start then
        table.insert(out, line:sub(pos, hit_start))
        pos = hit_start + 1
      else
        table.insert(out, line:sub(pos, value_start - 1))
        table.insert(out, MASK)
        -- `redact_tokens` runs first; a value that's already the mask
        -- marker was counted there, so don't count it again here.
        if line:sub(value_start, value_end) ~= MASK then
          count = count + 1
        end
        pos = value_end + 1
      end
    end
  end

  return table.concat(out), count
end

local PEM_BEGIN = "^%-%-%-%-%-BEGIN [%u ]-PRIVATE KEY%-%-%-%-%-$"
local PEM_END = "^%-%-%-%-%-END [%u ]-PRIVATE KEY%-%-%-%-%-$"

-- M.scan(lines) -> redacted_lines, count
-- Pure: never mutates `lines`. `redacted_lines` is line-for-line identical
-- to `lines` when count == 0.
function M.scan(lines)
  local out, count, in_pem = {}, 0, false

  for _, line in ipairs(lines) do
    if in_pem then
      if line:match(PEM_END) then
        in_pem = false
        table.insert(out, line)
      end
      -- inner PEM body lines are dropped; the single marker below stands in
    elseif line:match(PEM_BEGIN) then
      in_pem = true
      count = count + 1
      table.insert(out, line)
      table.insert(out, MASK .. " PRIVATE KEY BODY")
    else
      local redacted, token_count = redact_tokens(line)
      local redacted2, assign_count = redact_assignments(redacted)
      count = count + token_count + assign_count
      table.insert(out, redacted2)
    end
  end

  return out, count
end

-- M.apply_range(bufnr, start_line, end_line) -> count
-- 1-indexed, inclusive (Vim `:{range}` convention). Side-effecting: rewrites
-- only that slice of the buffer when secrets are found; a no-op (no
-- `nvim_buf_set_lines` call) otherwise. Defaults to the whole buffer.
-- Works on any buffer — no prompt session required; this is the primitive
-- behind both `:PromptRedact` and the automatic `BufWritePre` hook.
function M.apply_range(bufnr, start_line, end_line)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  start_line = start_line or 1
  end_line = end_line or vim.api.nvim_buf_line_count(bufnr)

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local redacted, count = M.scan(lines)
  if count > 0 then
    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, redacted)
  end
  return count
end

-- M.apply(bufnr) -> count
-- Whole-buffer shorthand for `M.apply_range`.
function M.apply(bufnr)
  return M.apply_range(bufnr, 1, nil)
end

return M
