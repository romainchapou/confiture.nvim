local internal = {}
local utils = require("confiture.utils")

local function replace_variables_in_string(val_str, variables, line, line_nb)
  local ret_string = val_str

  for to_replace in string.gmatch(val_str, "%${([%a_]+)}") do
    if variables[to_replace] ~= nil then
      ret_string = string.gsub(ret_string, "${" .. to_replace .. "}", "\"" .. variables[to_replace] .. "\"")
    else
      utils.warn('Failed to replace undeclared variable "' .. to_replace ..
                 '" in line' .. line_nb .. ': "' .. line .. '"' )
    end
  end

  return ret_string
end

local function parse_command(line, state_to_update)
  local parsing_successful = false

  for key, val in string.gmatch(line, "@([%a_]+)%s*:%s*\"(.*)\"") do
    parsing_successful = true

    val = replace_variables_in_string(val, state_to_update.variables, line)
    state_to_update.commands[key] = val

    break
  end

  return parsing_successful
end

local function parse_variable(line, state_to_update)
  local parsing_successful = false

  for key, val in string.gmatch(line, "([%a_]+)%s*:%s*\"(.*)\"") do
    parsing_successful = true

    val = replace_variables_in_string(val, state_to_update.variables, line)
    state_to_update.variables[key] = val

    break
  end

  return parsing_successful
end

local function check_boolean_variable_val(state, var)
  if state.variables[var] ~= "true" and state.variables[var] ~= "false" then
    utils.warn('Configuration file error: invalid ' .. var .. ' value "' .. state.variables[var]
               .. '", should be "true" or "false"')
    return false
  end

  return true
end

-- 'config_file' supposed to exist
function internal.read_configuration_file(config_file)
  local state = {
    variables = {
      src_folder = vim.fn.getcwd(), -- @Cleanup: remove this ?
      RUN_IN_TERM = "true",
      DISPATCH_BUILD = "true",
      COMPILER = "",
    },

    commands = {
      -- possible commands:
      --   configure
      --   build
      --   run
      --   clean
    }
  }

  local line_nb = 1

  for line in io.lines(config_file) do
    local parsing_successful = false

    -- ignoring comments and empty lines
    if string.match(line, "^%s*$") or string.match(line, "^%s*#") == '#' then
      parsing_successful = true
    else
      line = string.gsub(line, "^%s*(.*)", "%1")

      -- commands are declared with a '@', variables are not
      local first_char = string.sub(line, 1, 1)

      if first_char == '@' then
        parsing_successful = parse_command(line, state)
      else
        parsing_successful = parse_variable(line, state)
      end
    end

    if not parsing_successful then
      utils.warn('Configuration file error line ' .. line_nb .. ': "' .. line .. '"')
      return nil
    end

    line_nb = line_nb + 1
  end

  if not check_boolean_variable_val(state, "RUN_IN_TERM")    then return nil end
  if not check_boolean_variable_val(state, "DISPATCH_BUILD") then return nil end

  return state
end

return internal
