local confiture = {}
local utils = require("confiture.utils")

local function has_error_in_quickfix_list()
  for entry_nb, entry in pairs(vim.api.nvim_call_function("getqflist", {})) do
    if entry_nb == 1 and string.match(entry.text, "^%s*command not found:") then
      return true
    end

    if string.match(entry.text, "^%s*%l*%s*error: ") then
      return true
    end
  end

  return false
end


local function build_with(makeprg, compiler, should_dispatch)
  -- apply correct settings and then restore the user's values
  local saved_makeprg = vim.api.nvim_get_option_value("makeprg", {scope = 'local'})

  local saved_errorformat = vim.api.nvim_get_option_value("errorformat", {scope = 'local'})

  local saved_current_compiler = vim.b.current_compiler -- may be nil

  if compiler ~= "" then
    vim.api.nvim_command(":compiler " .. compiler)
  end

  vim.api.nvim_set_option_value("makeprg", makeprg, {scope = 'local'})

  local has_dispatch_plugin = vim.fn.exists(":AbortDispatch") == 2

  -- cancel dispatch build to be sure we are not running multiple builds at a time
  if has_dispatch_plugin then
    vim.api.nvim_command(":silent AbortDispatch")
  end

  -- use tpope/vim-dispatch if available and asked for
  -- ('should_dispatch' should be false for build_and_run)
  if should_dispatch and has_dispatch_plugin then
    vim.api.nvim_command(":Make")
  else
    vim.api.nvim_command(":make!")
  end

  -- restoring user's :compiler value is done by setting back those two variables and makeprg and errorformat
  vim.b.current_compiler = saved_current_compiler
  vim.g.current_compiler = saved_current_compiler -- @Unsure

  vim.api.nvim_set_option_value("errorformat", saved_errorformat, {scope = 'local'})

  vim.api.nvim_set_option_value("makeprg", saved_makeprg, {scope = 'local'})
end

local function build_and_check_success(state)
  -- change 'shellpipe' to actually catch the error code of ':make' as explained here:
  -- https://vi.stackexchange.com/questions/26947/check-if-make-fails
  local shell = vim.api.nvim_get_option_value("shell", {scope = 'local'})
  local saved_shellpipe = vim.api.nvim_get_option_value("shellpipe", {scope = 'local'})
  local should_parse_qf_list = false

  if string.match(shell, "[^%a]?zsh$") then
    vim.api.nvim_set_option_value("shellpipe", ' 2>&1| tee %s; exit ${pipestatus[1]}', {scope = 'local'})
  elseif string.match(shell, "[^%a]?bash$") then
    vim.api.nvim_set_option_value("shellpipe", ' 2>&1| tee %s; exit ${PIPESTATUS[0]}', {scope = 'local'})
  else
    -- if no standard shell found, we can't get the error code from a shellpipe modification,
    -- so resort to parsing the quickfix list (which is not robust)
    should_parse_qf_list = true
  end

  confiture.build(state, true)

  vim.api.nvim_set_option_value("shellpipe", saved_shellpipe, {scope = 'local'})

  -- return true on success
  if should_parse_qf_list then
    return not has_error_in_quickfix_list()
  else
    return vim.v.shell_error == 0
  end
end

function confiture.build(state, from_build_and_run)
  local should_dispatch = not from_build_and_run and state.variables.DISPATCH_BUILD

  build_with(state.commands.build, state.variables.COMPILER, should_dispatch)
end

function confiture.run(state)
  if state.variables.RUN_IN_TERM then
    -- choose what looks better between a horizontal and a vertical split
    local win_width =  vim.api.nvim_call_function("winwidth", {0}) / 2
    local win_height = vim.api.nvim_call_function("winheight", {0})

    if win_width > 1.5 * win_height then
      vim.api.nvim_command("vsplit")
    else
      vim.api.nvim_command("split")
    end

    vim.api.nvim_command("terminal " .. state.commands.run)
    vim.api.nvim_command("startinsert")
  else
    vim.api.nvim_command(":! " .. state.commands.run)
  end
end

function confiture.build_and_run(state)
  -- if no build command, just launch the run command
  local do_build = state.commands.build ~= nil
  local build_success

  if do_build then build_success = build_and_check_success(state) end

  if not do_build or build_success then
    confiture.run(state)
  else
    utils.warn("Build command failed")
  end
end

-- 'cmd' is the argument given to the :Confiture command.
-- It should correspond to a command defined in the config file (or 'build_and_run').
-- This function will do some checks, separate the special cases (build, run
-- and build_and_run) and launch the command
function confiture.command_launcher(cmd)
  local config_file = utils.configuration_file_name

  if not utils.file_exists(config_file) then
    return utils.warn("Configuration file not found, can't run command")
  end

  local state = require("confiture.internal").read_configuration_file(config_file)

  if state == nil then return end -- parsing error

  if cmd == "build_and_run" then
    if state.commands.run ~= nil then
      confiture.build_and_run(state)
    else
      return utils.warn('Command "run" undefined in configuration file')
    end
    return
  end

  if state.commands[cmd] == nil then
    return utils.warn('Command "' .. cmd .. '" undefined in configuration file')
  end

  if cmd == "build"  or cmd == "run" then -- build and run are special
    return confiture[cmd](state)
  else
    vim.api.nvim_command(":! " .. state.commands[cmd])
  end
end

return confiture
