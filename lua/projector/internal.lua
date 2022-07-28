local internal = {}
local settings = require("projector.settings")

function internal.read_configuration_file(file)
  for line in io.lines(file) do
    local parsing_successful = false

    -- ignoring comments and empty lines
    if #line == 0 or string.match(line, "^%s*#") == '#' then
      parsing_successful = true
    else
      for key, val in string.gmatch(line, "([%a_]+) ?: ?\"(.*)\"") do
        parsing_successful = true

        if settings[key] ~= nil then
          settings[key] = val
        else
          print("Warning: projector: config file key not found: " .. key)
        end

        break
      end
    end

    if not parsing_successful then
      print("Warning: projector: config file line error: " .. line)
    end
  end

  settings["src_folder"] = vim.fn.getcwd()
end

return internal
