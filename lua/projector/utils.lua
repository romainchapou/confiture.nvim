local utils = {}

utils.configuration_file_name = "projector.conf"

function utils.file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

return utils