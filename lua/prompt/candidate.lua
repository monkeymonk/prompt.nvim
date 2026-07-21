local M = {}

function M.normalize(item, ctx)
  return {
    label = item.label or item.insert_text or "",
    insert_text = item.insert_text or item.label or "",
    kind = item.kind or "file",
    detail = item.detail,
    documentation = item.documentation,
    source = item.source or "unknown",
    target = item.target or (ctx and ctx.target) or nil,
    scope = item.scope,
    path = item.path,
    sort_text = item.sort_text or item.label or item.insert_text or "",
    filter_text = item.filter_text or item.label or item.insert_text or "",
    deprecated = item.deprecated,
    metadata = item.metadata,
  }
end

function M.normalize_all(items, ctx)
  local result = {}
  for _, item in ipairs(items) do
    -- Skip malformed (non-table) items rather than indexing them: a source
    -- returning a stray non-table would otherwise error inside the aggregator's
    -- finish(), which is swallowed by its xpcall and silently hangs the whole
    -- completion request (the outer callback never fires).
    if type(item) == "table" then
      table.insert(result, M.normalize(item, ctx))
    end
  end
  return result
end

return M
