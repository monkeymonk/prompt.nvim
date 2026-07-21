-- Minimal POSIX-ish shell lexer used ONLY to figure out what kind of word is
-- under the cursor (command name vs. argument/path) for completion purposes.
-- This module never executes or spawns anything -- it is pure string parsing.
local M = {}

-- Tokenize `line` into a flat list of tokens:
--   { type = "word", value = <literal text, quotes/escapes resolved>,
--     raw_start = <1-based col>, raw_end = <1-based col>,
--     unterminated_quote = <bool> }
--   { type = "op", value = "|" | "&&" | "&" | ";" | ">" | ">>" | "<" }
-- `line` is assumed to end exactly at the cursor (nothing after it), so the
-- last token -- if it is a word that runs to the end of the string with no
-- trailing whitespace -- represents the word still being typed.
function M.tokenize(line)
  local tokens = {}
  local i = 1
  local n = #line

  local function peek(off)
    return line:sub(i + off, i + off)
  end

  while i <= n do
    local c = line:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif c == "&" and peek(1) == "&" then
      tokens[#tokens + 1] = { type = "op", value = "&&" }
      i = i + 2
    elseif c == ">" and peek(1) == ">" then
      tokens[#tokens + 1] = { type = "op", value = ">>" }
      i = i + 2
    elseif c == "|" or c == ";" or c == ">" or c == "<" then
      tokens[#tokens + 1] = { type = "op", value = c }
      i = i + 1
    elseif c == "&" then
      tokens[#tokens + 1] = { type = "op", value = "&" }
      i = i + 1
    else
      local start = i
      local value = {}
      local quote = nil -- nil | "'" | '"'
      while i <= n do
        local ch = line:sub(i, i)
        if quote == "'" then
          -- Single quotes: everything is literal, no escapes.
          if ch == "'" then
            quote = nil
            i = i + 1
          else
            value[#value + 1] = ch
            i = i + 1
          end
        elseif quote == '"' then
          -- Double quotes: backslash escapes ", \, $, ` only; otherwise
          -- literal (including whitespace).
          if
            ch == "\\"
            and i < n
            and (peek(1) == '"' or peek(1) == "\\" or peek(1) == "$" or peek(1) == "`")
          then
            value[#value + 1] = peek(1)
            i = i + 2
          elseif ch == '"' then
            quote = nil
            i = i + 1
          else
            value[#value + 1] = ch
            i = i + 1
          end
        else
          -- Unquoted.
          if ch == "'" then
            quote = "'"
            i = i + 1
          elseif ch == '"' then
            quote = '"'
            i = i + 1
          elseif ch == "\\" then
            if i < n then
              value[#value + 1] = peek(1)
              i = i + 2
            else
              i = i + 1 -- trailing backslash at EOL: drop it
            end
          elseif ch:match("%s") then
            break
          elseif ch == "|" or ch == ";" or ch == "&" or ch == ">" or ch == "<" then
            break
          else
            value[#value + 1] = ch
            i = i + 1
          end
        end
      end
      tokens[#tokens + 1] = {
        type = "word",
        value = table.concat(value),
        raw_start = start,
        raw_end = i - 1,
        unterminated_quote = quote ~= nil,
      }
    end
  end

  return tokens
end

-- A completed word looks like a leading assignment ("FOO=bar", "FOO=").
local function looks_like_assignment(word)
  return word:match("^[%a_][%w_]*=") ~= nil
end

-- Inspect `line` (text up to the cursor) and describe the word under the
-- cursor for completion routing.
--   segment_words     -- completed words in the current command segment
--                         (the segment ends at the last unquoted |, &&, ; --
--                         or starts at the beginning of the line)
--   current_word      -- literal text of the word still being typed (quotes
--                         and escapes resolved); "" if the cursor is at a
--                         fresh word boundary (after whitespace/an operator)
--   is_command_position -- true if `current_word` is the command name of the
--                           current segment (nothing but assignments, and no
--                           redirection operator, precede it)
--   assignment_prefix  -- true if `current_word` itself looks like a leading
--                         "VAR=..." assignment still being typed
function M.current(line)
  line = line or ""
  local tokens = M.tokenize(line)
  local n = #line
  local ends_with_ws = n == 0 or line:sub(n, n):match("%s") ~= nil

  local current_word = ""
  local completed = tokens
  local last = tokens[#tokens]
  if last and last.type == "word" and not ends_with_ws and last.raw_end == n then
    current_word = last.value
    completed = {}
    for idx = 1, #tokens - 1 do
      completed[idx] = tokens[idx]
    end
  end

  -- Current segment = everything after the last unquoted |, &&, ; among the
  -- completed tokens (or from the start if there is none).
  local seg_start = 1
  for idx = #completed, 1, -1 do
    local t = completed[idx]
    if t.type == "op" and (t.value == "|" or t.value == "&&" or t.value == ";") then
      seg_start = idx + 1
      break
    end
  end

  local segment_words = {}
  local prev_op = nil -- the op token, if any, immediately before current_word
  for idx = seg_start, #completed do
    local t = completed[idx]
    if t.type == "word" then
      segment_words[#segment_words + 1] = t.value
      prev_op = nil
    else
      prev_op = t.value
    end
  end

  -- A redirection target (`>`, `>>`, `<`) is always a path, never a command.
  local redirected = prev_op == ">" or prev_op == ">>" or prev_op == "<"

  local assignment_prefix = looks_like_assignment(current_word)

  -- The command word is the first non-assignment word of the segment; if any
  -- such word already exists among the completed words, the current word is
  -- an argument, not the command.
  local has_command_word = false
  for _, w in ipairs(segment_words) do
    if not looks_like_assignment(w) then
      has_command_word = true
      break
    end
  end

  local is_command_position = (not redirected) and not has_command_word and not assignment_prefix

  return {
    segment_words = segment_words,
    current_word = current_word,
    is_command_position = is_command_position,
    assignment_prefix = assignment_prefix,
  }
end

return M
