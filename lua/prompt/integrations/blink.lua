--- blink.cmp source for prompt.nvim
local source = {}

function source.new(_opts)
  return setmetatable({}, { __index = source })
end

function source:enabled()
  return require("prompt.buffer").is_attached(0)
end

function source:get_trigger_characters()
  return require("prompt.registry").trigger_characters()
end

function source:get_completions(_context, callback)
  -- Build prompt.nvim context from the current buffer/window.
  local ctx = require("prompt.context").build(_context and _context.bufnr or nil)

  local CIK = vim.lsp.protocol.CompletionItemKind
  local kind_map = {
    file = CIK.File,
    directory = CIK.Folder,
    command = CIK.Function,
    skill = CIK.Snippet,
    agent = CIK.Interface,
    prompt = CIK.Text,
    buffer = CIK.File,
    symbol = CIK.Variable,
    resource = CIK.Reference,
  }

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
        kind = kind_map[c.kind] or CIK.Text,
        filterText = c.filter_text or c.label,
        sortText = string.format("%05d", i),
        insertText = c.insert_text,
        detail = c.detail,
        documentation = doc,
        deprecated = c.deprecated or false,
        -- Replace exactly the query region (text after the trigger char), 0-based LSP range.
        textEdit = {
          newText = c.insert_text,
          range = {
            start = { line = ctx.row - 1, character = ctx.query_col or ctx.col },
            ["end"] = { line = ctx.row - 1, character = ctx.col },
          },
        },
      }
    end
    callback({
      is_incomplete_backward = true,
      is_incomplete_forward = true,
      items = items,
    })
  end)

  -- Return a no-op cancellation function.
  return function() end
end

return source
