local projector = {}
local settings = require("projector.settings")

function projector.configure()
  os.execute(settings.configure_command)
end

function projector.build()
  vim.api.nvim_command(":make! "  .. settings.build_flags)
end

function projector.run()
  -- TODO launch nvim terminal running the executable, or simply launch the executable, depending on another parameter

  vim.api.nvim_command(":!cd " .. settings.build_folder .. " && " .. settings.run_command)
end

function projector.build_and_run()
  projector.build()
  projector.run()
end

-- TODO un reload du fichier de conf

return projector
