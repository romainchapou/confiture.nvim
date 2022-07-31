local confiture = {}
local settings = require("confiture.settings")

local function has_error_in_quickfix_list(error_match_str)
  for _, entry in pairs(vim.api.nvim_call_function("getqflist", {})) do
    if string.match(entry.text, error_match_str) then
      return true
    end
  end

  return false
end


function confiture.configure()
  os.execute(settings.configure_command)
end

function confiture.build()
  vim.api.nvim_command(":make! "  .. settings.build_flags)
end

function confiture.clean()
  os.execute(settings.clean_command)
end

function confiture.run()
  if settings.run_command_in_term == "true" then
    local win_width =  vim.api.nvim_call_function("winwidth", {0}) / 2
    local win_height = vim.api.nvim_call_function("winheight", {0})

    if win_width > 1.5 * win_height then
      vim.api.nvim_command("vsplit")
    else
      vim.api.nvim_command("split")
    end

    vim.api.nvim_command("terminal " .. settings.run_command)
  else
    vim.api.nvim_command(":! " .. settings.run_command)
  end
end

function confiture.build_and_run()
  confiture.build()

  -- we can't easely get the error code of `:make` so parse the quickfix list instead
  if not has_error_in_quickfix_list(settings.error_match_str) then
    confiture.run()
  end
end

return confiture
