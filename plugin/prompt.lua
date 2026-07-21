if vim.g.loaded_prompt then
  return
end
vim.g.loaded_prompt = true

-- Register the bridge auto-attach, existing-server remote attach, and session
-- lifecycle guards even before setup() is called, so the external-editor flow
-- (fresh process AND `--server`) works with zero configuration on a real
-- package install. All three are idempotent (named, cleared augroups), so a
-- later setup() re-registering them is harmless.
local prompt = require("prompt")
prompt.setup_bridge()
prompt.setup_remote()
prompt.setup_lifecycle()
