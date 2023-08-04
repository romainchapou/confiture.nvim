local utils = {}

function utils.warn(msg)
  vim.notify("Confiture: " .. msg, vim.log.levels.WARN, { title = 'Confiture' })
end

function utils.file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

function utils.has_dispatch_plugin()
  return vim.fn.exists(":AbortDispatch") == 2
end


return utils
