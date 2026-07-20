local M = {}

local levels = { trace = 0, debug = 1, info = 2, warn = 3, error = 4, off = 5 }

function M.log(level, msg)
  local threshold = levels[require("prompt.config").get().log.level] or levels.warn
  if (levels[level] or levels.info) < threshold then
    return
  end
  local severity = (level == "warn" and vim.log.levels.WARN)
    or (level == "error" and vim.log.levels.ERROR)
    or vim.log.levels.INFO
  vim.notify("[prompt] " .. msg, severity)
end

function M.debug(msg)
  M.log("debug", msg)
end

function M.info(msg)
  M.log("info", msg)
end

function M.warn(msg)
  M.log("warn", msg)
end

function M.error(msg)
  M.log("error", msg)
end

return M
