local confiture = {}
local utils = require("confiture.utils")

--
-- The public API
--


local function get_state(should_log)
  return require("confiture.executor").get_state(should_log)
end

function confiture.get_variable(var_name)
  local state = get_state(false)

  if not state then return nil end

  return state.variables[var_name]
end

function confiture.get_command(cmd_name)
  local state = get_state(false)

  if not state then return nil end

  return state.commands[cmd_name]
end

-- WARNING: this will overwrite the variable 'var' in you confiture config file.
function confiture.set_variable(var, value)
  require("confiture.internal").replace_in_config_file(var, value, true)
end

-- WARNING: this will overwrite the command 'cmd' in you confiture config file.
function confiture.set_command(cmd, value)
  require("confiture.internal").replace_in_config_file(cmd, value, false)
end

-- synchronous build, return success as a boolean
function confiture.build_and_return_success()
  local state = get_state(true)

  if state == nil then return false end -- parsing error

  if state.commands.build == nil then
    utils.warn('Command "build" undefined in configuration file')
    return false
  end

  return require("confiture.executor").build_and_check_success(state)
end

-- async build, will exec the `on_success` callback if successful
function confiture.async_build_and_exec_on_success(on_success)
  local state = get_state(true)

  if state == nil then return end -- parsing error

  if state.commands.build == nil then
    return utils.warn('Command "build" undefined in configuration file')
  end

  if not utils.has_dispatch_plugin() then
    return utils.warn("Can't dispatch command as tpope/vim-dispatch plugin not found")
  end

  require("confiture.executor").internal_build_async_and_exec_callback(state, on_success)
end


return confiture
