local settings = {
  -- src_folder to be set in read_configuration_file
  run_command_in_term = "false",

  configure_command = "",
  build_flags = "-j16 -C ${src_folder}",
  run_command = "",
}

return settings
