local internal = {}
local settings = require("projector.settings")

local function replace_variables_in_string(val_str)
  local ret_string = val_str

  for to_replace in string.gmatch(val_str, "%${([%a_]+)}") do
    if settings[to_replace] ~= nil then
      ret_string = string.gsub(ret_string, "${" .. to_replace .. "}", "\"" .. settings[to_replace] .. "\"")
    else
      print("Failed to replace variable " .. to_replace)
    end
  end

  return ret_string
end

function internal.read_configuration_file(file)
  settings["src_folder"] = vim.fn.getcwd()

  for line in io.lines(file) do
    local parsing_successful = false

    -- ignoring comments and empty lines
    if string.match(line, "^%s*$") or string.match(line, "^%s*#") == '#' then
      parsing_successful = true
    else
      for key, val in string.gmatch(line, "([%a_]+) ?: ?\"(.*)\"") do
        parsing_successful = true

        val = replace_variables_in_string(val)
        settings[key] = val

        break
      end
    end

    if not parsing_successful then
      print("Warning: projector: config file line error: " .. line)
    end
  end
end

return internal
