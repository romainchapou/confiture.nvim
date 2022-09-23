local function confiture_launch_default(cmd)
  require("confiture").command_launcher(cmd.args, "default")
end

local function confiture_launch_term(cmd)
  require("confiture").command_launcher(cmd.args, "terminal")
end

local function confiture_launch_dispatch(cmd)
  require("confiture").command_launcher(cmd.args, "dispatch")
end


local function confiture_complete_full(arg)
  -- add 'build_and_run' in completion options
  return require("confiture.completion").confiture_complete(arg, true)
end

local function confiture_complete_simple(arg)
  return require("confiture.completion").confiture_complete(arg, false)
end

vim.api.nvim_create_user_command(
  "Confiture",
  confiture_launch_default,
  { nargs = 1, complete = confiture_complete_full }
)

vim.api.nvim_create_user_command(
  "ConfitureTerm",
  confiture_launch_term,
  { nargs = 1, complete = confiture_complete_simple }
)

vim.api.nvim_create_user_command(
  "ConfitureDispatch",
  confiture_launch_dispatch,
  { nargs = 1, complete = confiture_complete_simple }
)
