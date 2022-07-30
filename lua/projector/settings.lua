local settings = {
  -- src_folder to be added in read_configuration_file
  build_folder = "./build", -- expressed relative to src_folder

  configure_command = "",
  build_flags = "-j16 -C ${src_folder}/${build_folder}",
  run_command = "",
}

return settings
