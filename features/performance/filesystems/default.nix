{
  config,
  lib,
  pkgs,
  ...
}: {
  # Performance filesystems configuration

  # Configure file systems for performance
  fileSystems = {
    # Optimize /tmp for performance
    "/tmp" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = ["size=2G" "mode=1777"];
    };

    # Optimize /var/tmp for performance
    "/var/tmp" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = ["size=1G" "mode=1777"];
    };
  };
}
