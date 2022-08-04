local confiture = {}
local utils = require("confiture.utils")

local function config_file_not_read()
  if package.loaded["confiture.internal"] == nil then
    utils.warn("Faild to launch command, no config file")
    return true
  end

  return false
end

local function has_error_in_quickfix_list(error_match_str)
  for _, entry in pairs(vim.api.nvim_call_function("getqflist", {})) do
    if string.match(entry.text, error_match_str) then
      return true
    end
  end

  return false
end


function confiture.configure()
  if config_file_not_read() then return end

  vim.api.nvim_command(":! " .. require("confiture.settings").configure_command)
end

function confiture.build()
  if config_file_not_read() then return end

  local settings = require("confiture.settings")

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

function confiture.clean()
  if config_file_not_read() then return end

  vim.api.nvim_command(":! " .. require("confiture.settings").clean_command)
end

function confiture.run()
  if config_file_not_read() then return end

  local settings = require("confiture.settings")

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

function confiture.build_and_run()
  if config_file_not_read() then return end

  confiture.build()

  -- we can't easely get the error code of `:make` so parse the quickfix list instead
  if not has_error_in_quickfix_list(require("confiture.settings").error_match_str) then
    confiture.run()
  else
    utils.warn("Build command failed")
  end
end

function confiture.reload()
  local saved_src_folder = require("confiture.settings").src_folder

  -- unload the settings
  package.loaded["confiture.settings"] = nil

  local new_settings = require("confiture.settings")

  new_settings.src_folder = saved_src_folder

  require("confiture.internal").read_configuration_file(new_settings)
end

return confiture
