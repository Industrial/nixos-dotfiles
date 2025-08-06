{
  config,
  lib,
  pkgs,
  ...
}: {
  # AppArmor security configuration

  security = {
    # Enable AppArmor for application sandboxing
    apparmor = {
      enable = true;
      # Enable AppArmor profiles
      packages = [pkgs.apparmor-profiles];
    };
  };
}
