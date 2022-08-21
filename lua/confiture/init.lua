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


function confiture.configure(state)
  vim.api.nvim_command(":! " .. state.commands.configure)
end

local function build_with(makeprg, flags, should_dispatch)
  -- apply correct makeprg and then restore the user's setting
  local saved_makeprg = vim.api.nvim_get_option("makeprg")

  vim.api.nvim_set_option("makeprg", makeprg)

  local has_dispatch_plugin = vim.fn.exists(":Make") == 2

  -- cancel dispatch build to be sure we are not running multiple builds at a time
  if has_dispatch_plugin then
    vim.api.nvim_command(":silent AbortDispatch")
  end

  -- use tpope/vim-dispatch if available and asked for
  -- ('should_dispatch' should be false for build_and_run)
  if should_dispatch and has_dispatch_plugin then
    vim.api.nvim_command(":Make "  .. flags)
  else
    vim.api.nvim_command(":make! "  .. flags)
  end

  vim.api.nvim_set_option("makeprg", saved_makeprg)
end

local function build_and_check_success(state)
  -- change 'shellpipe' to actually catch the error code of ':make' as explained here:
  -- https://vi.stackexchange.com/questions/26947/check-if-make-fails
  local shell = vim.api.nvim_get_option("shell")
  local saved_shellpipe = vim.api.nvim_get_option("shellpipe")
  local should_parse_qf_list = false

  if string.match(shell, "[^%a]?zsh$") then
    vim.api.nvim_set_option("shellpipe", ' 2>&1| tee %s; exit ${pipestatus[1]}')
  elseif string.match(shell, "[^%a]?bash$") then
    vim.api.nvim_set_option("shellpipe", ' 2>&1| tee %s; exit ${PIPESTATUS[0]}')
  else
    -- if no standard shell found, we can't get the error code from a shellpipe modification,
    -- so resort to parsing the quickfix list
    should_parse_qf_list = true
  end

  confiture.build(state, true)

  vim.api.nvim_set_option("shellpipe", saved_shellpipe)

  -- return true on success
  if should_parse_qf_list then
    return not has_error_in_quickfix_list()
  else
    return vim.v.shell_error == 0
  end
end

function confiture.build(state, from_build_and_run)
  local parse_build_command_str = "^([%a_-]+)%s*(.*)"

  local makeprg = string.gsub(state.commands.build, parse_build_command_str, "%1")
  local build_flags = string.gsub(state.commands.build, parse_build_command_str, "%2")

  local should_dispatch = not from_build_and_run and state.variables.DISPATCH_BUILD == "true"

  build_with(makeprg, build_flags, should_dispatch)
end

function confiture.clean(state)
  vim.api.nvim_command(":! " .. state.commands.clean)
end

function confiture.run(state)
  if state.variables.RUN_IN_TERM == "true" then
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
-- This function will then launch the related 'confiture' function.
function confiture.command_launcher(cmd)
  if confiture[cmd] == nil then
    return utils.warn('"' .. cmd .. '" is not a valid command name')
  end

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

  confiture[cmd](state)
end

return confiture
