local confiture = {}
local utils = require("confiture.utils")

local function has_error_in_quickfix_list(error_match_str)
  for entry_nb, entry in pairs(vim.api.nvim_call_function("getqflist", {})) do
    if entry_nb == 1 and string.match(entry.text, "^%s*command not found:") then
      return true
    end

    if string.match(entry.text, error_match_str) then
      return true
    end
  end

  return false
end


function confiture.configure(state)
  vim.api.nvim_command(":! " .. state.commands.configure)
end

local function build_with(makeprg, flags)
  -- apply correct makeprg and then restore the user's setting
  local saved_makeprg = vim.api.nvim_get_option("makeprg")

  vim.api.nvim_set_option("makeprg", makeprg)

  vim.api.nvim_command(":make! "  .. flags)

  vim.api.nvim_set_option("makeprg", saved_makeprg)
end

function confiture.build(state)
  local parse_build_command_str = "^([%a_-]+)%s*(.*)"

  local makeprg = string.gsub(state.commands.build, parse_build_command_str, "%1")
  local build_flags = string.gsub(state.commands.build, parse_build_command_str, "%2")

  build_with(makeprg, build_flags)
end

function confiture.clean(state)
  vim.api.nvim_command(":! " .. state.commands.clean)
end

function confiture.run(state)
  if state.variables.run_command_in_term == "true" then
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

  if do_build then confiture.build(state) end

  -- we can't easely get the error code of `:make` so parse the quickfix list instead
  -- TODO @Improve: this will fail to detect the case where the build tool fails if no build config file found.
  if not do_build or not has_error_in_quickfix_list(state.variables.error_match_str) then
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
      confiture[cmd](state)
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
