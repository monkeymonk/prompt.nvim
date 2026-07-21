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

function source:get_completions(context, callback)
  -- Build prompt.nvim context from the current buffer/window.
  local ctx = require("prompt.context").build(context and context.bufnr or nil)
  local bufnr = ctx.bufnr
  local captured_target = ctx.target
  local captured_row = ctx.row

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

  -- Return the real cancel function from the aggregator so blink.cmp can abort
  -- in-flight sources (e.g. filesystem scans) when superseded or aborted.
  return require("prompt.completion").complete(ctx, function(ranked)
    -- Drop stale results: buffer gone, target changed, or cursor moved away
    -- from the query region since this request was issued.
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    if ctx.target ~= captured_target then
      return
    end
    local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
    if not ok then
      return
    end
    local row, col = cursor[1], cursor[2]
    local query_col = ctx.query_col or ctx.col
    if row ~= captured_row or col < query_col then
      return
    end

    local items = {}
    for i, c in ipairs(ranked or {}) do
      local doc
      if c.documentation then
        local value = type(c.documentation) == "table" and table.concat(c.documentation, "\n")
          or c.documentation
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
end

return source
