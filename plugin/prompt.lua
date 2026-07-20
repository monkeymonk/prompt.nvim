if vim.g.loaded_prompt then
  return
end
vim.g.loaded_prompt = true

-- Register the bridge auto-attach even before setup() is called, so the
-- external-editor flow works with zero configuration on a real package install.
require("prompt").setup_bridge()
