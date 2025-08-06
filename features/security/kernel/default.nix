{
  config,
  lib,
  pkgs,
  ...
}: {
  # Kernel security configuration

  security = {
    # Configure unprivileged user namespaces
    unprivilegedUsernsClone = {
      enable = true;
    };

    # Configure protect kernel modules
    protectKernelImage = true;

    # Configure lock kernel modules
    lockKernelModules = true;

    # Configure hidepid
    hidepid = 2;

    # Configure kernel lockdown
    kernelLockdown = "integrity";

    # Configure secure boot
    secureBoot = {
      enable = true;
    };

    # Configure virtual memory protection
    virtualisation = {
      protectHostname = true;
    };
  };

  # Configure users for security
  users = {
    # Configure default user security
    defaultUserShell = pkgs.bash;

    # Configure user security settings
    users = lib.mkIf (config.security.hidepid == 2) {
      # Hide user processes from other users
      "nobody" = {
        uid = 65534;
        group = "nobody";
        description = "Unprivileged user";
        home = "/var/empty";
        shell = "/run/current-system/sw/bin/nologin";
      };
    };
  };

  # Configure file system security
  fileSystems = lib.mkIf (config.security.hidepid == 2) {
    "/proc" = {
      device = "proc";
      fsType = "proc";
      options = ["hidepid=2" "gid=proc"];
    };
  };
}
