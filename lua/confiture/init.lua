local confiture = {}
local utils = require("confiture.utils")

local function has_error_in_quickfix_list(error_match_str)
  for entry_nb, entry in pairs(vim.api.nvim_call_function("getqflist", {})) do
    if entry_nb == 1 and string.match(entry.text, "command not found:") then
      return true
    end

    if string.match(entry.text, error_match_str) then
      return true
    end
  end

  return false
end


function confiture.configure(settings)
  vim.api.nvim_command(":! " .. settings.configure_command)
end

local function build_with(makeprg, flags)
  -- apply correct makeprg and then restore the user's setting
  local saved_makeprg = vim.api.nvim_get_option("makeprg")

  vim.api.nvim_set_option("makeprg", makeprg)

  vim.api.nvim_command(":make! "  .. flags)

  vim.api.nvim_set_option("makeprg", saved_makeprg)
end

function confiture.build(settings)
  -- TODO with new command support, check in command_launcher that the "build" command is defined
  if settings.build_command ~= nil then
    local makeprg = string.gsub(settings.build_command, "^([%a_-]+)%s*(.*)", "%1")
    local build_flags = string.gsub(settings.build_command, "^([%a_-]+)%s*(.*)", "%2")
    build_with(makeprg, build_flags)
  end
end

function confiture.clean(settings)
  vim.api.nvim_command(":! " .. settings.clean_command)
end

function confiture.run(settings)
  if settings.run_command_in_term == "true" then
    local win_width =  vim.api.nvim_call_function("winwidth", {0}) / 2
    local win_height = vim.api.nvim_call_function("winheight", {0})

    if win_width > 1.5 * win_height then
      vim.api.nvim_command("vsplit")
    else
      vim.api.nvim_command("split")
    end

    vim.api.nvim_command("terminal " .. settings.run_command)
    vim.api.nvim_command("startinsert")
  else
    vim.api.nvim_command(":! " .. settings.run_command)
  end
end

function confiture.build_and_run(settings)
  -- if no build command, just launch the run command
  local do_build = settings.build_command ~= nil

  if do_build then confiture.build(settings) end

  -- we can't easely get the error code of `:make` so parse the quickfix list instead
  if not do_build or not has_error_in_quickfix_list(settings.error_match_str) then
    confiture.run(settings)
  else
    utils.warn("Build command failed")
  end
end

function confiture.command_launcher(command)
  if confiture[command] == nil then
    return utils.warn('"' .. command .. '" is not a valid command name')
  end

  local config_file = utils.configuration_file_name

  if not utils.file_exists(config_file) then
    return utils.warn("Configuration file not found, can't run command")
  end

  local settings = require("confiture.internal").read_configuration_file(config_file)

  if settings == nil then return end -- parsing error

  confiture[command](settings)
end

return confiture
