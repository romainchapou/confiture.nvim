-- see if the file exists
local function file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

local projector_file_name = "projector.conf"

if file_exists(projector_file_name) then
  require("projector.internal").read_configuration_file(projector_file_name)
end
