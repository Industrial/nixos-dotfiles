{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    nushell
  ];

  # Note: Nushell configuration files (config.nu, env.nu) are managed separately
  # in ~/.config/nushell/ to allow for easier customization and testing
  #
  # To switch to Nushell interactively:
  #   1. Type 'nu' from Fish
  #   2. Or use: exec nu
  #
  # Fish remains the default login shell for stability and POSIX compatibility
}
