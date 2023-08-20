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

local function replace_variables_in_string(val_str, variables, target_type, err)
  local ret_string = val_str

  for to_replace in string.gmatch(val_str, "%${([%w_]*)}") do
    if variables[to_replace] ~= nil then
      if type(variables[to_replace]) == "string" then
        -- add quotes here in case of spaces, but only when substituing to a command
        if target_type == "command" then
          ret_string = string.gsub(ret_string, "${" .. to_replace .. "}", "\"" .. variables[to_replace] .. "\"")
        else
          ret_string = string.gsub(ret_string, "${" .. to_replace .. "}", variables[to_replace])
        end
      else
        err.msg = 'Failed to replace ' .. type(variables[to_replace]) .. ' variable "' .. to_replace .. '" (should be of type string)'
        return nil
      end
    else
      err.msg = 'Failed to replace undeclared variable "' .. to_replace .. '"'
      return nil
    end
  end

  return ret_string
end


-- A valid command definition should be of the form:
--      @command_name : "script to run"
--
-- A valid variable definition should be of the form:
--      variable_name : "string value"
-- or:
--      variable_name : boolean_value
local function parse_command_or_var_and_add_to_state(tokens, state_to_update, override_data)
  local first_token_type = tokens[1].type

  if first_token_type ~= "command" and first_token_type ~= "variable" then
    return "not a command or variable definition (first token of type " .. first_token_type .. ")"
  end

  -- skip this line if var/cmd in override_data
  if override_data ~= nil then
    if first_token_type == "command" and override_data.cmd ~= nil then
      if tokens[1].value == override_data.cmd.name then
        return
      end
    end

    if first_token_type == "variable" and override_data.var ~= nil then
      if tokens[1].value == override_data.var.name then
        return
      end
    end
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
    output.value = replace_variables_in_string(output.value, state_to_update.variables,
                                               first_token_type, err)
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
function internal.read_configuration_file(config_file, override_data)
  local state = {
    variables = {
      src_folder = vim.fn.getcwd(), -- @Cleanup: remove this ?
      RUN_IN_TERM = true,
      DISPATCH_BUILD = true,
      COMPILER = "",
    },

    commands = {}
  }

  if override_data ~= nil then
    if override_data.var ~= nil then
      state.variables[override_data.var.name] = override_data.var.value
    end

    if override_data.cmd ~= nil then
      state.commands[override_data.cmd.name] = override_data.cmd.value
    end
  end

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
      local err_msg = parse_command_or_var_and_add_to_state(parsed_tokens, state, override_data)

      if err_msg then
        warn_parsing(line_nb, err_msg)
        return nil
      end
    end

    line_nb = line_nb + 1
  end

  if not check_boolean_variable_val(state, "RUN_IN_TERM")    then return nil end
  if not check_boolean_variable_val(state, "DISPATCH_BUILD") then return nil end

  if state.commands['build_and_run'] ~= nil then
    utils.warn("Configuration file error: the 'build_and_run' command shouldn't be manually defined")
    return nil
  end

  -- support '"' escaping
  -- IMPORTANT: do this at the very end to apply it only once
  for _, var_value in pairs(state.variables) do
    if (type(var_value) == "string") then
      var_value = string.gsub(var_value, '\\"', '"')
    end
  end

  return state
end

-- @Optim: using a builtin tool would be quicker, but less portable
-- from https://forum.cockos.com/showthread.php?t=244397
local function copy_file(old_path, new_path)
  local old_file = io.open(old_path, "rb")
  local new_file = io.open(new_path, "wb")
  local old_file_sz, new_file_sz = 0, 0

  if not old_file or not new_file then
    return false
  end

  while true do
    local block = old_file:read(2^13)
    if not block then
      old_file_sz = old_file:seek("end")
      break
    end
    new_file:write(block)
  end

  old_file:close()
  new_file_sz = new_file:seek("end")
  new_file:close()
  return new_file_sz == old_file_sz
end

function internal.replace_in_config_file(key, value, is_replace_variable)
  -- TODO start by checking if the config file is opened in a buffer, and if so, if it has unsaved changes

  local pattern, replacement

  if is_replace_variable then
    pattern = "^%s*" .. key .. "%s*:%s*\".*\""
    replacement = key .. ": \"" .. value .. "\""
  else
    pattern = "^%s*@" .. key .. "%s*:%s*\".*\""
    replacement = "@" .. key .. ": \"" .. value .. "\""
  end

  local config_file_path = vim.g.confiture_file_name
  local temp_file_path = os.tmpname()

  local previous_state = internal.read_configuration_file(config_file_path)

  if previous_state == nil then
    utils.warn("can't set_[command,variable] as " .. config_file_path .. " failed parsing")
    return
  end

  local copy_success = copy_file(config_file_path, temp_file_path)

  if not copy_success then
    utils.warn("failed to initialize " .. config_file_path .. " backup file for set_command")
    return
  end

  local confiture_file = io.open(config_file_path, "w")

  if confiture_file == nil then
    utils.warn("failed to open " .. config_file_path .. " for set_command")
    return
  end

  for line in io.lines(temp_file_path) do
    local new_line = line:gsub(pattern, replacement)
    confiture_file:write(new_line, "\n")
  end

  confiture_file:close()

  -- Checking that the parsing of the new config file gives the same
  -- information, except for the changed key
  -- Note: this should never return false and it is a bit expensive, but we
  -- have to be very cautious as we are overwriting a user config file
  local function new_file_is_coherent()
    local new_state_with_override

    if is_replace_variable then
      new_state_with_override = internal.read_configuration_file(config_file_path, {
        var = { name = key, value = previous_state.variables[key]}
      })
    else
      new_state_with_override = internal.read_configuration_file(config_file_path, {
        cmd = { name = key, value = previous_state.commands[key]}
      })
    end

    if new_state_with_override == nil then return false end

    for var, old_val in pairs(previous_state.variables) do
      if new_state_with_override.variables[var] ~= old_val then
        return false
      end
    end

    for cmd, old_val in pairs(previous_state.commands) do
      if new_state_with_override.commands[cmd] ~= old_val then
        return false
      end
    end

    return true
  end

  if new_file_is_coherent() then
    -- we can safely remove the temporary file at this point
    os.remove(temp_file_path)
  else
    utils.warn("set_command failed, backup of " .. config_file_path .. " is " .. temp_file_path)
  end

  -- TODO reload the confiture file buffer
end

return internal
