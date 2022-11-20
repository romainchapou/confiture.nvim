local function confiture_launch_default(cmd)
  require("confiture").command_launcher(cmd.args, "default")
end

local function confiture_launch_term(cmd)
  require("confiture").command_launcher(cmd.args, "terminal")
end

local function confiture_launch_dispatch(cmd)
  require("confiture").command_launcher(cmd.args, "dispatch")
end

local function confiture_launch_toggle_term(cmd)
  require("confiture").command_launcher(cmd.args, "toggle_term", cmd.count)
end


local function confiture_complete_full(arg)
  -- add 'build_and_run' in completion options
  return require("confiture.completion").confiture_complete(arg, true)
end

local function confiture_complete_simple(arg)
  return require("confiture.completion").confiture_complete(arg, false)
end

-- declaration of confiture commands
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

-- this accepts a count for the ToggleTerm to target (see toggleterm.nvim's documentation)
vim.api.nvim_create_user_command(
  "ConfitureSendToToggleTerm",
  confiture_launch_toggle_term,
  { count = true, nargs = 1, complete = confiture_complete_simple }
)

-- set the default config file name
if vim.g.confiture_file_name == nil then
  vim.g.confiture_file_name = "project.conf"
end

-- use the 'conf' syntax highlighting for the config file
local group = vim.api.nvim_create_augroup("confiture_autocmds", {})

vim.api.nvim_create_autocmd({"BufNewFile", "BufRead"}, {
  group = group,
  pattern = vim.g.confiture_file_name,

  -- @Cleanup: could move this to a syntax file
  callback = function()
    vim.api.nvim_command("setlocal syntax=conf")

    -- add some colors for the 'true' and 'false' key words
    -- @Unsure that this is the correct way to do it, but it looks like it's
    -- only affecting the config file, which is what we want
    vim.api.nvim_command("syntax match ConfitureBooleans '\\<\\(true\\|false\\)\\>'")
    vim.api.nvim_command("hi link ConfitureBooleans Boolean")

    -- highlight the strings to be substituted with the '${...}' syntax
    vim.api.nvim_command("syntax match ConfitureStringToSubstitute '\\(\\$\\|@\\){\\w*}' containedin=ALL")
    vim.api.nvim_command("hi link ConfitureStringToSubstitute Special")
  end
})
