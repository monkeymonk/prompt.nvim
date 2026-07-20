local M = {}

-- Shared path completion for the "files" and "directories" sources. In segment
-- mode (query contains "/" or starts with "~") it lists the immediate entries of
-- the resolved directory, showing the bare basename while inserting the full
-- path. Otherwise it uses the recursive repo scan. `opts`:
--   entry_type  "file" | "directory"        which fs entries to keep
--   kind        candidate kind
--   source      candidate source name
--   repo_field  "files" | "directories"      which M.list result field to use
--   decorate    optional fn(path) -> string  (e.g. append a trailing slash)
function M.complete(ctx, callback, opts)
  local cfg = require("prompt.config").get()
  local fs = require("prompt.connectors.filesystem")
  local decorate = opts.decorate or function(s)
    return s
  end
  local spec = fs.resolve_query(ctx.root, ctx.query)

  if spec.mode == "segment" then
    local show_hidden = cfg.paths.include_hidden or spec.base:sub(1, 1) == "."
    fs.list_dir(spec.dir, function(entries)
      local items = {}
      for _, e in ipairs(entries) do
        if e.type == opts.entry_type and (show_hidden or e.name:sub(1, 1) ~= ".") then
          local full = decorate(spec.prefix .. e.name)
          table.insert(items, {
            label = decorate(e.name),
            insert_text = full,
            filter_text = full,
            kind = opts.kind,
            source = opts.source,
            path = spec.dir .. "/" .. e.name,
          })
        end
      end
      callback(items)
    end)
    return
  end

  fs.list(ctx.root, {
    include_hidden = cfg.paths.include_hidden,
    respect_gitignore = cfg.paths.respect_gitignore,
    ignore = cfg.paths.ignore,
    max_results = cfg.paths.max_results,
    max_depth = cfg.paths.max_depth,
  }, function(res)
    local items = {}
    for _, rel in ipairs(res[opts.repo_field] or {}) do
      local text = decorate(rel)
      table.insert(items, {
        label = text,
        insert_text = text,
        filter_text = text,
        kind = opts.kind,
        source = opts.source,
        path = rel,
      })
    end
    callback(items)
  end)
end

return M
