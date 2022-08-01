local utils = require("confiture.utils")

-- try to read the config file at startup
if utils.file_exists(utils.configuration_file_name) then
  local settings = require("confiture.settings")

  require("confiture.internal").read_configuration_file(settings)
end

local function confiture_launch(cmd)
  local func = cmd.args

  if require("confiture")[func] == nil then
    utils.warn("Command not found:" .. func)
  else
    -- launch the function defined in lua/confiture/init.lua
    require("confiture")[func]()
  end
end

local function confiture_complete(arg)
  local matches = {}

  for command in pairs(require("confiture")) do
    if vim.startswith(command, arg) then
      table.insert(matches, command)
    end
  end

  return matches
end

vim.api.nvim_create_user_command("Confiture", confiture_launch, { nargs = 1, complete = confiture_complete })
