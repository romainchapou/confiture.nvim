local function confiture_launch(cmd)
  local func = cmd.args

  require("confiture").command_runner(func)
end

local function confiture_complete(arg)
  local matches = {}

  for command in pairs(require("confiture")) do
    if command ~= "command_runner" and vim.startswith(command, arg) then
      table.insert(matches, command)
    end
  end

  return matches
end

vim.api.nvim_create_user_command("Confiture", confiture_launch, { nargs = 1, complete = confiture_complete })
