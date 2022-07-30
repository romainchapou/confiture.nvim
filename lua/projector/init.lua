local projector = {}
local settings = require("projector.settings")

function projector.configure()
  os.execute(settings.configure_command)
end

function projector.build()
  vim.api.nvim_command(":make! "  .. settings.build_flags)
end

function projector.run()
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

function projector.build_and_run()
  projector.build()
  projector.run()
end

return projector
