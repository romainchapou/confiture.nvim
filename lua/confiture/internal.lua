local internal = {}
local utils = require("confiture.utils")

local function replace_variables_in_string(val_str, settings, line, line_nb)
  local ret_string = val_str

  for to_replace in string.gmatch(val_str, "%${([%a_]+)}") do
    if settings[to_replace] ~= nil then
      ret_string = string.gsub(ret_string, "${" .. to_replace .. "}", "\"" .. settings[to_replace] .. "\"")
    else
      utils.warn('Failed to replace undeclared variable "' .. to_replace ..
                 '" in line' .. line_nb .. ': "' .. line .. '"' )
    end
  end

  return ret_string
end

function internal.read_configuration_file(config_file)
  local settings = {
    src_folder = vim.fn.getcwd(), -- @Cleanup: remove this ?
    error_match_str = "^%s*%l*%s*error: ",
    run_command_in_term = "true", -- TODO check this is true or false after parsing

    configure_command = "",
    clean_command = "",
    run_command = "",
  }

  local line_nb = 1

  for line in io.lines(config_file) do
    local parsing_successful = false

    -- ignoring comments and empty lines
    if string.match(line, "^%s*$") or string.match(line, "^%s*#") == '#' then
      parsing_successful = true
    else
      for key, val in string.gmatch(line, "([%a_]+) ?: ?\"(.*)\"") do
        if key == "src_folder" then
          utils.warn("You shouldn't manually define src_folder (done in line: " .. line .. ")")
        end

        parsing_successful = true

        val = replace_variables_in_string(val, settings, line)
        settings[key] = val

        break
      end
    end

    if not parsing_successful then
      utils.warn('Configuration file error line ' .. line_nb .. ': "' .. line .. '"')
      return nil
    end

    line_nb = line_nb + 1
  end

  return settings
end

return internal
