local confiture_file_name = require("confiture.utils").configuration_file_name

if require("confiture.utils").file_exists(confiture_file_name) then
  local settings = require("confiture.settings")

  require("confiture.internal").read_configuration_file(settings)
end

vim.api.nvim_create_user_command("ConfitureReload", require("confiture").reload, { nargs = 0 })
vim.api.nvim_create_user_command("ConfitureConfigure", require("confiture").configure, { nargs = 0 })
vim.api.nvim_create_user_command("ConfitureBuild", require("confiture").build, { nargs = 0 })
vim.api.nvim_create_user_command("ConfitureRun", require("confiture").run, { nargs = 0 })
vim.api.nvim_create_user_command("ConfitureBuildAndRun", require("confiture").build_and_run, { nargs = 0 })
vim.api.nvim_create_user_command("ConfitureClean", require("confiture").clean, { nargs = 0 })
