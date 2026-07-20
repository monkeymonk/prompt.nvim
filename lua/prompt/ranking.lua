local M = {}

local function fuzzy(query, text)
  if query == "" then
    return 0
  end

  local q = query:lower()
  local t = text:lower()

  local score = 0
  local qi = 1
  local last_match = nil

  for ti = 1, #t do
    if qi > #q then
      break
    end

    if t:sub(ti, ti) == q:sub(qi, qi) then
      if last_match and ti == last_match + 1 then
        score = score + 3
      else
        score = score + 1
      end
      last_match = ti
      qi = qi + 1
    end
  end

  if qi <= #q then
    return nil
  end

  return score
end

function M.score(candidate, ctx)
  local query = ctx.query or ""
  local label = candidate.filter_text or candidate.label or ""

  local base = fuzzy(query, label)
  if base == nil then
    return nil
  end

  local s = base * 10

  local low = label:lower()
  local q = query:lower()

  if q ~= "" and low:sub(1, #q) == q then
    s = s + 1000
  end

  if candidate.path and ctx._open_buffers and ctx._open_buffers[candidate.path] then
    s = s + 500
  end

  local base_name = (label:match("([^/]+)$")) or label
  if q ~= "" and base_name:lower():sub(1, #q) == q then
    s = s + 100
  end

  local _, segs = label:gsub("/", "")
  s = s + math.max(0, 50 - segs * 2)

  if label:match("^%.") or label:match("/%.") then
    s = s - 25
  end

  return s
end

function M.sort(candidates, ctx)
  local scored = {}
  for _, candidate in ipairs(candidates) do
    local s = M.score(candidate, ctx)
    if s ~= nil then
      table.insert(scored, { candidate = candidate, score = s })
    end
  end

  table.sort(scored, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end
    return (a.candidate.label or "") < (b.candidate.label or "")
  end)

  local max_results = ctx._max_results or require("prompt.config").get().completion.max_results

  local result = {}
  for i = 1, math.min(#scored, max_results) do
    table.insert(result, scored[i].candidate)
  end

  return result
end

return M
