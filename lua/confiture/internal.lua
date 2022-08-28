local internal = {}
local utils = require("confiture.utils")

local function replace_commands_in_string(val_str, commands, err)
  local ret_string = val_str

  for to_replace in string.gmatch(val_str, "@{([%w_]*)}") do
    if commands[to_replace] ~= nil then
      -- don't add quotes here, paste the command directly
      ret_string = string.gsub(ret_string, "@{" .. to_replace .. "}", commands[to_replace])
    else
      err.msg = 'Failed to replace undeclared command "@' .. to_replace .. '"'
      return
    end
  end

  return ret_string
end

local function replace_variables_in_string(val_str, variables, err)
  local ret_string = val_str

  for to_replace in string.gmatch(val_str, "%${([%w_]*)}") do
    if variables[to_replace] ~= nil then
      if type(variables[to_replace]) == "string" then
        -- add quotes here in case of spaces
        ret_string = string.gsub(ret_string, "${" .. to_replace .. "}", "\"" .. variables[to_replace] .. "\"")
      else
        err.msg = 'Failed to replace ' .. type(variables[to_replace]) .. ' variable "' .. to_replace .. '"'
        return nil
      end
    else
      err.msg = 'Failed to replace undeclared variable "' .. to_replace .. '"'
      return nil
    end
  end

  ret_string = string.gsub(ret_string, '\\"', '"') -- support '"' escaping

  return ret_string
end


-- A valid command definition should be of the form:
--      @command_name : "script to run"
--
-- A valid variable definition should be of the form:
--      variable_name : "string value"
-- or:
--      variable_name : boolean_value
local function parse_command_or_var_and_add_to_state(tokens, state_to_update)
  local first_token_type = tokens[1].type

  if first_token_type ~= "command" and first_token_type ~= "variable" then
    return "not a command or variable definition (first token of type " .. first_token_type
  end

  if not tokens[2] or tokens[2].type ~= "separator" then
    return "not a command or variable definition, missing ':' separator"
  end

  if #tokens <= 2 then
    return "incomplete " .. first_token_type .. " definition, missing value"
  end

  local output = {
    name = tokens[1].value,
    value = nil
  }

  local i = 3
  if tokens[i] and tokens[i].type == "script_str" or
    (first_token_type == "variable" and tokens[i].type == "boolean") then
    output.value = tokens[i].value
    i = i + 1
  elseif tokens[i] and first_token_type == "variable" then
    return "variable value should be a string or a boolean"
  elseif tokens[i] and first_token_type == "command" then
    return "command value should be a script string"
  else
    return "incomplete variable definition, missing value"
  end

  if tokens[i] then
    return "invalid extra token '" .. tokens[i].value .. "' of type " .. tokens[i].type
  end

  if type(output.value) == "string" then
    local err = {}

    output.value = replace_commands_in_string(output.value, state_to_update.commands, err)
    if err.msg then return err.msg end
    output.value = replace_variables_in_string(output.value, state_to_update.variables, err)
    if err.msg then return err.msg end
  end

  if first_token_type == "variable" then
    state_to_update.variables[output.name] = output.value
  elseif first_token_type == "command" then
    state_to_update.commands[output.name] = output.value
  else
    utils.warn("This should never happen")
  end
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
      local err_msg = parse_command_or_var_and_add_to_state(parsed_tokens, state)

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
