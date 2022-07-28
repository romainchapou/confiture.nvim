local projector = {}
local settings = require("projector.settings")

function projector.build()
  os.execute("mkdir -p " .. settings.src_folder .. "/" .. settings.build_folder)
  vim.api.nvim_command(":make! -C " .. settings.build_folder .. " " .. settings.build_flags)
end

function projector.run()
  -- TODO launch nvim terminal running the executable, or simply launch the executable, depending on another parameter

  vim.api.nvim_command(":!cd " .. settings.build_folder .. " && " .. settings.run_command)
end

function projector.build_and_run()
  projector.build()
  projector.run()
end

-- TODO setting "use_make" : si true, utiliser make avec les flags donnés, si
-- false utiliser un commande custom donnée
-- TODO voir pour substitution de variable dans le projector.conf pour à terme
-- écrire une fonction "configure" sympathique
-- TODO un reload du fichier de conf

return projector
