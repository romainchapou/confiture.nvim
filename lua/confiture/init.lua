local confiture = {}
local utils = require("confiture.utils")

local function has_error_in_quickfix_list(error_match_str)
  for _, entry in pairs(vim.api.nvim_call_function("getqflist", {})) do
    if string.match(entry.text, error_match_str) then
      return true
    end
  end

  return false
end


function confiture.configure(settings)
  vim.api.nvim_command(":! " .. settings.configure_command)
end

function confiture.build(settings)
  -- apply correct makeprg and then restore the user's setting
  local saved_makeprg = vim.api.nvim_get_option("makeprg")

  if settings.makeprg ~= nil then
    vim.api.nvim_set_option("makeprg", settings.makeprg)
  end

  vim.api.nvim_command(":make! "  .. settings.build_flags)

  if settings.makeprg ~= nil then
    vim.api.nvim_set_option("makeprg", saved_makeprg)
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
  confiture.build(settings)

  -- we can't easely get the error code of `:make` so parse the quickfix list instead
  if not has_error_in_quickfix_list(settings.error_match_str) then
    confiture.run(settings)
  else
    utils.warn("Build command failed")
  end
end

function confiture.command_runner(command)
  local config_file = utils.configuration_file_name

  if not utils.file_exists(config_file) then
    utils.warn("Configuration file not found, can't run command")
    return
  end

  local settings = require("confiture.internal").read_configuration_file(config_file)

  if settings == nil then return end

  confiture[command](settings)
end

return confiture
