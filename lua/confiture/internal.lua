local internal = {}
local utils = require("confiture.utils")

local function replace_variables_in_string(val_str, settings, line)
  local ret_string = val_str

  for to_replace in string.gmatch(val_str, "%${([%a_]+)}") do
    if settings[to_replace] ~= nil then
      ret_string = string.gsub(ret_string, "${" .. to_replace .. "}", "\"" .. settings[to_replace] .. "\"")
    else
      utils.warn('Failed to replace variable "' .. to_replace .. '" in line "' .. line .. '"' )
    end
  end

  return ret_string
end

function internal.read_configuration_file(settings_to_change)
  if settings_to_change.src_folder == nil then
    settings_to_change.src_folder = vim.fn.getcwd()
  end

  local config_file = settings_to_change.src_folder .. "/" .. utils.configuration_file_name

  if not utils.file_exists(config_file) then
    -- unload the settings
    package.loaded["confiture.settings"] = nil
    utils.warn("Configuration file not found")
    return
  end

  for line in io.lines(config_file) do
    local parsing_successful = false

    -- ignoring comments and empty lines
    if string.match(line, "^%s*$") or string.match(line, "^%s*#") == '#' then
      parsing_successful = true
    else
      for key, val in string.gmatch(line, "([%a_]+) ?: ?\"(.*)\"") do
        parsing_successful = true

        val = replace_variables_in_string(val, settings_to_change, line)
        settings_to_change[key] = val

        break
      end
    end

    if not parsing_successful then
      utils.warn("Config file line error: " .. line)
    end
  end
end

return internal
