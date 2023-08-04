local executor = {}
local utils = require("confiture.utils")

executor.has_pending_run = false
executor.on_sucessful_build_callback = function() end

-- TODO @Cleanup: most of this file should be move to an other file, and only
-- the public api functions should remain

local function has_error_in_quickfix_list()
  for entry_nb, entry in pairs(vim.api.nvim_call_function("getqflist", {})) do
    if entry_nb == 1 and string.match(entry.text, "^%s*command not found:") then
      return true
    end

    if string.match(entry.text, "^%s*%l*%s*error: ") then
      return true
    end
  end

  return false
end

if utils.has_dispatch_plugin() then
  -- register the autocmd to launch a callback after a successful build
  vim.api.nvim_create_autocmd("QuickFixCmdPost", {
    group = vim.api.nvim_create_augroup("confiture_post_build_autocmd", {}),
    pattern = "make",

    callback = function()
      if vim.fn["dispatch#request"] == nil then return end

      local last_dispatch_infos = vim.fn["dispatch#request"]()

      if executor.has_pending_run and tonumber(last_dispatch_infos.completed) == 1 then
        local status = tonumber(vim.fn.readfile(last_dispatch_infos.file .. '.complete')[1])

        if status == 0 then
          executor.on_sucessful_build_callback()
        else
          require("confiture.utils").warn("Build command failed")
        end

        executor.has_pending_run = false
      end
    end
  })
end

local function build_with(makeprg, compiler, should_dispatch)
  -- apply correct settings and then restore the user's values
  local saved_makeprg = vim.api.nvim_get_option_value("makeprg", {scope = 'local'})

  local saved_errorformat = vim.api.nvim_get_option_value("errorformat", {scope = 'local'})

  local saved_current_compiler = vim.b.current_compiler -- may be nil

  if compiler ~= "" then
    vim.api.nvim_command(":compiler " .. compiler)
  end

  vim.api.nvim_set_option_value("makeprg", makeprg, {scope = 'local'})

  local has_dispatch = utils.has_dispatch_plugin()

  -- cancel dispatch build to be sure we are not running multiple builds at a time
  if has_dispatch then
    vim.api.nvim_command(":silent AbortDispatch")
  end

  -- use tpope/vim-dispatch if available and asked for
  if should_dispatch and has_dispatch then
    vim.api.nvim_command(":Make")
  else
    vim.api.nvim_command(":make!")
  end

  -- restoring user's :compiler value is done by setting back those two variables and makeprg and errorformat
  vim.b.current_compiler = saved_current_compiler
  vim.g.current_compiler = saved_current_compiler -- @Unsure

  vim.api.nvim_set_option_value("errorformat", saved_errorformat, {scope = 'local'})

  vim.api.nvim_set_option_value("makeprg", saved_makeprg, {scope = 'local'})
end

local function build_and_check_success(state)
  -- change 'shellpipe' to actually catch the error code of ':make' as explained here:
  -- https://vi.stackexchange.com/questions/26947/check-if-make-fails
  local shell = vim.api.nvim_get_option_value("shell", {scope = 'local'})
  local saved_shellpipe = vim.api.nvim_get_option_value("shellpipe", {scope = 'local'})
  local should_parse_qf_list = false

  if string.match(shell, "[^%a]?zsh$") then
    vim.api.nvim_set_option_value("shellpipe", ' 2>&1| tee %s; exit ${pipestatus[1]}', {scope = 'local'})
  elseif string.match(shell, "[^%a]?bash$") then
    vim.api.nvim_set_option_value("shellpipe", ' 2>&1| tee %s; exit ${PIPESTATUS[0]}', {scope = 'local'})
  else
    -- if no standard shell found, we can't get the error code from a shellpipe modification,
    -- so resort to parsing the quickfix list (which is not robust)
    should_parse_qf_list = true
  end

  executor.build(state, true)

  vim.api.nvim_set_option_value("shellpipe", saved_shellpipe, {scope = 'local'})

  -- return true on success
  if should_parse_qf_list then
    return not has_error_in_quickfix_list()
  else
    return vim.v.shell_error == 0
  end
end

function executor.build(state, force_synchronous)
  local should_dispatch = not force_synchronous and state.variables.DISPATCH_BUILD

  build_with(state.commands.build, state.variables.COMPILER, should_dispatch)
end

-- TODO would be good to have more user control on the terminal creation
local function run_cmd_in_nvim_term(cmd, from_async_build_and_run)
    -- choose what looks better between a horizontal and a vertical split
    local win_width =  vim.api.nvim_call_function("winwidth", {0}) / 2
    local win_height = vim.api.nvim_call_function("winheight", {0})

    if win_width > 1.5 * win_height then
      vim.api.nvim_command("vnew")
    else
      vim.api.nvim_command("new")
    end

    vim.fn.termopen(cmd)

    if from_async_build_and_run then
      -- It seems that the TermOpen event will not be launched if this is
      -- executed in the callback to another event. To better support other
      -- plugins (ex: nostalgic-term.nvim), launch it directly.
      vim.cmd([[doautocmd TermOpen]])
    end

    vim.api.nvim_command("wincmd p")
end

function executor.run(state, from_async_build_and_run)
  if state.variables.RUN_IN_TERM then
    run_cmd_in_nvim_term(state.commands.run, from_async_build_and_run)
  else
    vim.api.nvim_command(":! " .. state.commands.run)
  end
end

function executor.internal_build_async_and_exec_callback(state, on_success_callback)
  executor.on_sucessful_build_callback = on_success_callback

  -- Setting this to true will launch the run command when the build
  -- successfully finishes. See the QuickFixCmdPost autocmd in
  -- plugin/confiture.lua
  executor.has_pending_run = true

  build_with(state.commands.build, state.variables.COMPILER, true)
end

function executor.build_and_run(state)
  -- no build command, simply exec the run command
  if state.commands.build == nil then
    executor.run(state, false)
    return
  end

  if not utils.has_dispatch_plugin() or not state.variables.DISPATCH_BUILD then
    -- fallback to a synchronous build and run
    local build_success = build_and_check_success(state)

    if build_success then
      executor.run(state, false)
    else
      utils.warn("Build command failed")
    end
  else
    executor.internal_build_async_and_exec_callback(state, function()
      executor.run(state, true)
    end)
  end
end

function executor.get_state(should_log)
  local config_file = vim.g.confiture_file_name

  if not utils.file_exists(config_file) then
    if should_log then
      utils.warn("Configuration file '" .. config_file .. "' not found, can't run command")
    end

    return
  end

  return require("confiture.internal").read_configuration_file(config_file)
end

-- 'cmd' is the argument given to the :Confiture command.
-- It should correspond to a command defined in the config file (or 'build_and_run').
-- This function will do some checks, separate the special cases (build, run
-- and build_and_run for cmd_type == "defaults") and launch the command
-- according to cmd_type
function executor.command_launcher(cmd, cmd_type)
  local state = executor.get_state(true)

  if state == nil then return end -- parsing error

  if cmd == "build_and_run" then
    if cmd_type ~= "default" then
      return utils.warn("build_and_run should be launched with a simple call to"
                        .. "':Confiture', not ':ConfitureTerm' or ':ConfitureDispatch'")
    end

    if state.commands.run ~= nil then
      executor.build_and_run(state)
    else
      return utils.warn('Command "run" undefined in configuration file')
    end
    return
  end

  if state.commands[cmd] == nil then
    return utils.warn('Command "' .. cmd .. '" undefined in configuration file')
  end

  if cmd_type == "default" then
    if cmd == "build" or cmd == "run" then -- build and run are special
      return executor[cmd](state)
    else
      vim.api.nvim_command(":! " .. state.commands[cmd])
    end
  elseif cmd_type == "dispatch" then
    if not utils.has_dispatch_plugin() then
      return utils.warn("Can't dispatch command as tpope/vim-dispatch plugin not found")
    end

    if cmd == "build" then -- use the build wrapper instead of :Dispatch directly
      return build_with(state.commands.build, state.variables.COMPILER, true)
    end

    -- @Unsure: we could do a :AbortDispatch here to make sure the user is not
    -- running multiple build commands that may be conflicting, but as we still
    -- want the user to be able do dispatch multiple commands, so no
    -- :AbortDispatch for now
    vim.api.nvim_command(":Dispatch " .. state.commands[cmd])
  elseif cmd_type == "terminal" then
    run_cmd_in_nvim_term(state.commands[cmd])
  else
      return utils.warn('Internal error: unknow cmd_type:' .. cmd_type)
  end
end

return executor
