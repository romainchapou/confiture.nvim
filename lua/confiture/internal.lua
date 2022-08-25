local internal = {}
local utils = require("confiture.utils")

local function replace_variables_in_string(val_str, variables, line_nb)
  local ret_string = val_str

  for to_replace in string.gmatch(val_str, "%${([%w_]+)}") do
    if variables[to_replace] ~= nil then
      ret_string = string.gsub(ret_string, "${" .. to_replace .. "}", "\"" .. variables[to_replace] .. "\"")
    else
      utils.warn('Failed to replace undeclared variable "' .. to_replace .. '" in line' .. line_nb)
      return nil
    end
  end

  ret_string = string.gsub(ret_string, '\\"', '"') -- support '"' escaping

  return ret_string
end

-- A valid command definition should be of the form:
--      @command_name : [@first_dep_cmd @second_dep_cmd ...] <"script to run">
--
-- * any number of dependent commands possible, including 0
-- * if one or more dependent command, having a script to run is optional
-- * if no dependent command, having a script to run is required
local function parse_command(tokens, state_to_update, line_nb)
  if #tokens <= 2 then
    return "incomplete command definition, missing value"
  end

  local command = {
    name = tokens[1].value,
    dependencies = {},
    script = nil
  }

  local i = 3
  while tokens[i] and tokens[i].type == "command" do
    table.insert(command.dependencies, tokens[i].value)
    i = i + 1
  end

  if tokens[i] and tokens[i].type == "script_str" then
    command.script = tokens[i].value
    i = i + 1
  end

  if tokens[i] then
    return "invalid extra token '" .. tokens[i].value .. "' of type " .. tokens[i].type
  end

  command.script = replace_variables_in_string(command.script, state_to_update.variables, line_nb)

  -- TODO @Incomplete take dependencies into account
  state_to_update.commands[command.name] = command.script
end

-- A valid variable definition should be of the form:
--      variable_name : "string value"
-- or:
--      variable_name : boolean_value
local function parse_variable(tokens, state_to_update, line_nb)
  if #tokens <= 2 then
    return "incomplete variable definition, missing value"
  end

  local variable = {
    name = tokens[1].value,
    value = nil
  }

  local i = 3
  if tokens[i] and tokens[i].type == "script_str" or tokens[i].type == "boolean" then
    variable.value = tokens[i].value
    i = i + 1
  end

  if tokens[i] then
    return "invalid extra token '" .. tokens[i].value .. "' of type " .. tokens[i].type
  end

  if type(variable.value) == "string" then
    variable.value = replace_variables_in_string(variable.value, state_to_update.variables, line_nb)
  end

  state_to_update.variables[variable.name] = variable.value
end

local function check_boolean_variable_val(state, var)
  if type(state.variables[var]) ~= "boolean" then
    utils.warn('Configuration file error: invalid ' .. var .. ' value: should be a boolean'
               .. ' (true or false), not a ' .. type(state.variables[var]))
    return false
  end

  return true
end

local function warn_parsing(line_nb, err_msg)
  utils.warn('Configuration file error line ' .. line_nb .. ': ' .. err_msg)
end

local function add_tokenized_line_infos_to_state(parsed_tokens, state, line_nb)
  local first_token_type = parsed_tokens[1].type

  local err_msg

  if first_token_type ~= "command" and first_token_type ~= "variable" then
    err_msg = "not a command or variable definition (first token of type " .. first_token_type
    return err_msg
  end

  if not parsed_tokens[2] or parsed_tokens[2].type ~= "separator" then
    err_msg =  "not a command or variable definition, missing ':' separator"
    return err_msg
  end

  if first_token_type == "command" then
    err_msg = parse_command(parsed_tokens, state, line_nb)
  else -- first_token_type == "variable"
    err_msg = parse_variable(parsed_tokens, state, line_nb)
  end

  return err_msg
end

-- 'config_file' supposed to exist
function internal.read_configuration_file(config_file)
  local state = {
    variables = {
      src_folder = vim.fn.getcwd(), -- @Cleanup: remove this ?
      RUN_IN_TERM = true,
      DISPATCH_BUILD = true,
      COMPILER = "",
    },

    commands = {}
  }

  local line_nb = 1

  for line in io.lines(config_file) do
    local parsed_tokens = require('confiture.parsing').tokenize(line)

    if type(parsed_tokens) == "string" then
      -- this is an error
      local parsing_err_msg = parsed_tokens
      warn_parsing(line_nb, parsing_err_msg)
      return nil
    end

    if #parsed_tokens ~= 0 then -- skip empty/comment lines
      local err_msg = add_tokenized_line_infos_to_state(parsed_tokens, state, line_nb)

      if err_msg then
        warn_parsing(line_nb, err_msg)
        return nil
      end
    end

    line_nb = line_nb + 1
  end

  if not check_boolean_variable_val(state, "RUN_IN_TERM")    then return nil end
  if not check_boolean_variable_val(state, "DISPATCH_BUILD") then return nil end

  return state
end

return internal
