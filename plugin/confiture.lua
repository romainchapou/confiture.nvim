local function confiture_launch(cmd)
  local arg = cmd.args

  require("confiture").command_launcher(arg)
end

local function confiture_complete(arg)
  local matches = {}
  local available_commands = require("confiture.completion")["available_commands"]()

  for _, command in pairs(available_commands) do
    if vim.startswith(command, arg) then
      table.insert(matches, command)
    end
  end

  return matches
end

vim.api.nvim_create_user_command("Confiture", confiture_launch, { nargs = 1, complete = confiture_complete })
