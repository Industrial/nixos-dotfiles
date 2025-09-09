{
  config,
  lib,
  pkgs,
  ...
}: {
  # Uptime Kuma monitoring
  services = {
    uptime-kuma = {
      enable = true;
      # Use the correct options for uptime-kuma
      package = pkgs.uptime-kuma;
      appriseSupport = true;
    };
  };

  # Create uptime-kuma user
  users = {
    users = {
      uptime-kuma = {
        isSystemUser = true;
        group = "uptime-kuma";
        home = "/var/lib/uptime-kuma";
        createHome = true;
      };
    };
    groups = {
      uptime-kuma = {};
    };
  };

  # Create data directory
  systemd = {
    tmpfiles = {
      rules = [
        "d /var/lib/uptime-kuma 0755 uptime-kuma uptime-kuma - -"
      ];
    };
  };
}
