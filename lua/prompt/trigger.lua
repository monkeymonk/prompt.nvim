local M = {}

local DEFAULT_ALLOW_AFTER = "[%s%(%[%{%:%;,]"

local function default_allow_after(prev)
  return prev == nil or prev:match(DEFAULT_ALLOW_AFTER) ~= nil
end

-- Build a completion result for a "word_query" trigger (e.g. shell mode `!`),
-- where the query is the current whitespace-delimited word under the cursor
-- rather than the whole tail. `i` is the 1-based position of the trigger char.
local function word_query_result(before, ch, i, trig)
  local token = before:match("%S*$") or ""
  local token_start = #before - #token -- 0-based column where the token begins
  local query, query_col
  if token_start == (i - 1) then
    -- Token abuts the trigger char (first word, e.g. "!cmd"): drop the trigger.
    query = token:sub(#ch + 1)
    query_col = (i - 1) + #ch
  else
    query = token
    query_col = token_start
  end
  return {
    trigger = ch,
    query = query,
    start_col = query_col,
    query_col = query_col,
    sources = trig.sources or {},
    trigger_def = trig,
  }
end

function M.parse(opts)
  local before
  if opts.before_cursor then
    before = opts.before_cursor
  elseif opts.line then
    before = opts.line:sub(1, opts.col)
  else
    before = ""
  end

  local triggers
  if opts.triggers then
    triggers = opts.triggers
  else
    local def
    if type(opts.target) == "string" then
      def = require("prompt.registry").get_target(opts.target)
    elseif type(opts.target) == "table" then
      def = opts.target
    end
    if not def then
      return nil
    end
    triggers = def.triggers or {}
  end

  -- Line-prefix (shell-style) triggers take precedence: if the line before the
  -- cursor begins, after optional whitespace, with a word_query trigger,
  -- complete in that mode regardless of other trigger chars later in the line.
  local ws = before:match("^(%s*)") or ""
  local first_ch = before:sub(#ws + 1, #ws + 1)
  local first_trig = first_ch ~= "" and triggers[first_ch] or nil
  if first_trig and first_trig.word_query and first_trig.enabled ~= false then
    if type(first_trig.enabled) ~= "function" or first_trig.enabled(opts) then
      return word_query_result(before, first_ch, #ws + 1, first_trig)
    end
  end

  for i = #before, 1, -1 do
    local ch = before:sub(i, i)
    local trig = triggers[ch]

    if trig then
      local enabled = true
      if trig.enabled == false then
        enabled = false
      elseif type(trig.enabled) == "function" then
        enabled = trig.enabled(opts) and true or false
      end

      if enabled then
        local query = before:sub(i + 1)
        local pattern = trig.query_pattern or "^[^%s]*$"

        if query:match(pattern) ~= nil then
          local prev = i > 1 and before:sub(i - 1, i - 1) or nil

          if prev == "\\" then
            return nil
          end

          local ok
          if trig.line_start_only then
            ok = before:sub(1, i - 1):match("^%s*$") ~= nil
          elseif type(trig.allow_after) == "function" then
            ok = trig.allow_after(prev, opts) and true or false
          else
            ok = default_allow_after(prev)
          end

          if ok then
            if trig.minimum_query_length and #query < trig.minimum_query_length then
              return nil
            end

            return {
              trigger = ch,
              query = query,
              start_col = i - 1,
              query_col = i,
              sources = trig.sources or {},
              trigger_def = trig,
            }
          end
        end
      end
    end
  end

  return nil
end

-- Is a trigger character at 1-based index `i` in `line` a valid reference start?
-- Shared boundary/escape/line-start rule used by whole-line scanners
-- (e.g. highlighting).
function M.is_valid(line, i, trig)
  local prev = i > 1 and line:sub(i - 1, i - 1) or nil
  if prev == "\\" then
    return false
  end
  local boundary = prev == nil or prev:match("%s") ~= nil or prev:match("[%(%[{:;,]") ~= nil
  if not boundary then
    return false
  end
  if trig and trig.line_start_only and line:sub(1, i - 1):match("^%s*$") == nil then
    return false
  end
  return true
end

-- Find every valid trigger occurrence in a full line. Returns an array of
-- { ch, trig, token, col_start (0-based), col_end (0-based, exclusive) }.
function M.scan_line(line, triggers)
  local out = {}
  for ch, trig in pairs(triggers) do
    local start_idx = 1
    while true do
      local i = line:find(ch, start_idx, true)
      if not i then
        break
      end
      if M.is_valid(line, i, trig) then
        local token = line:sub(i + 1):match("^[^%s]*") or ""
        if #token > 0 then
          out[#out + 1] = {
            ch = ch,
            trig = trig,
            token = token,
            col_start = i - 1,
            col_end = (i - 1) + 1 + #token,
          }
        end
      end
      start_idx = i + 1
    end
  end
  return out
end

return M
