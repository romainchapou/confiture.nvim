local projector_file_name = require("projector.utils").configuration_file_name

if require("projector.utils").file_exists(projector_file_name) then
  require("projector.settings").src_folder = vim.fn.getcwd()

  require("projector.internal").read_configuration_file()
end
