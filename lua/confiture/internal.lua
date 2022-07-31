local internal = {}
local utils = require("confiture.utils")
local settings = require("confiture.settings")

local function notify(msg, log_level)
  vim.notify("Confiture: " .. msg, log_level, { title = 'Confiture' })
end

local function replace_variables_in_string(val_str, line)
  local ret_string = val_str

  for to_replace in string.gmatch(val_str, "%${([%a_]+)}") do
    if settings[to_replace] ~= nil then
      ret_string = string.gsub(ret_string, "${" .. to_replace .. "}", "\"" .. settings[to_replace] .. "\"")
    else
      notify('Failed to replace variable "' .. to_replace .. '" in line "' .. line .. '"' , vim.log.levels.WARN)
    end
  end

  return ret_string
end

function internal.read_configuration_file()
  local config_file = settings.src_folder .. "/" .. utils.configuration_file_name

  for line in io.lines(config_file) do
    local parsing_successful = false

    -- ignoring comments and empty lines
    if string.match(line, "^%s*$") or string.match(line, "^%s*#") == '#' then
      parsing_successful = true
    else
      for key, val in string.gmatch(line, "([%a_]+) ?: ?\"(.*)\"") do
        parsing_successful = true

        val = replace_variables_in_string(val, line)
        settings[key] = val

        break
      end
    end

    if not parsing_successful then
      notify("Config file line error: " .. line, vim.log.levels.WARN)
    end
  end

  if settings.makeprg ~= nil then
    vim.api.nvim_set_option("makeprg", settings.makeprg)
  end
end

return internal
