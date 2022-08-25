local completion = {}
local utils = require("confiture.utils")

-- list available commands found in config file
function completion.available_commands()
  local config_file = utils.configuration_file_name

  local commands = {}
  local has_run_command = false

  if utils.file_exists(config_file) then
    for line in io.lines(config_file) do
      if not (string.match(line, "^%s*$") or string.match(line, "^%s*#") == '#') then
        local cmd_name = string.gmatch(line, "%s*@([%w_]*)%s*:.*")()

        if cmd_name then
          if cmd_name == 'run' then has_run_command = true end

          table.insert(commands, cmd_name)
        end
      end
    end

    if has_run_command then
      -- 'build_and_run' can be used if just 'run' is defined
      table.insert(commands, 'build_and_run')
    end
  end

  if #commands == 0 then
  -- if no command found in the config file, still give 'run' as a completion
  -- option so that the user can try to run it and see what is wrong
    table.insert(commands, 'run')
  end

  table.sort(commands, function(a, b) return a:upper() < b:upper() end)

  return commands
end

return completion
