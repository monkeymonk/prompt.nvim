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
    table.insert(result, M.normalize(item, ctx))
  end
  return result
end

return M
