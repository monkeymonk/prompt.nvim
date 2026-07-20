-- nvim-cmp source for prompt.nvim.
-- Register with:
--   require("cmp").register_source("prompt", require("prompt.integrations.cmp").new())
-- and add `{ name = "prompt" }` to your cmp sources.
local source = {}

function source.new()
  return setmetatable({}, { __index = source })
end

function source:is_available()
  return require("prompt.buffer").is_attached(0)
end

function source:get_trigger_characters()
  return require("prompt.registry").trigger_characters()
end

function source:get_keyword_pattern()
  -- Include path and trigger characters so cmp treats them as part of the word.
  return [[\%(\k\|[@/$!.~-]\)*]]
end

local KIND = {
  file = "File",
  directory = "Folder",
  command = "Function",
  skill = "Snippet",
  agent = "Interface",
  prompt = "Text",
  buffer = "File",
  symbol = "Variable",
  resource = "Reference",
}

function source:complete(_params, callback)
  local ctx = require("prompt.context").build()
  local CIK = vim.lsp.protocol.CompletionItemKind

  require("prompt.completion").complete(ctx, function(ranked)
    local items = {}
    for i, c in ipairs(ranked or {}) do
      local doc
      if c.documentation then
        local value = type(c.documentation) == "table" and table.concat(c.documentation, "\n") or c.documentation
        doc = { kind = "markdown", value = value }
      end
      items[#items + 1] = {
        label = c.label,
        kind = CIK[KIND[c.kind] or "Text"],
        insertText = c.insert_text,
        filterText = c.filter_text or c.label,
        sortText = string.format("%05d", i),
        documentation = doc,
        deprecated = c.deprecated or false,
        textEdit = {
          range = {
            start = { line = ctx.row - 1, character = ctx.query_col or ctx.col },
            ["end"] = { line = ctx.row - 1, character = ctx.col },
          },
          newText = c.insert_text,
        },
      }
    end
    callback({ items = items, isIncomplete = true })
  end)
end

return source
