{
  config,
  lib,
  pkgs,
  ...
}: {
  # Comprehensive systemd configuration with security and performance optimizations

  systemd = {
    oomd = {
      enable = true;
    };
  };

  # Configure services for performance and security
  services = {
    # Optimize cron for performance
    cron = {
      enable = true;
      systemCronJobs = [
        # Optimize system performance
        "0 2 * * * root /run/current-system/sw/bin/nix-collect-garbage -d"
        "0 3 * * * root /run/current-system/sw/bin/nix-store --optimise"
      ];
    };

    # Optimize timesyncd
    timesyncd = {
      enable = true;
    };

    # Optimize resolved
    resolved = {
      enable = true;
      extraConfig = ''
        DNS=1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4
        FallbackDNS=1.1.1.1 1.0.0.1
        DNSSEC=yes
        DNSOverTLS=yes
        MulticastDNS=yes
        LLMNR=yes
      '';
    };
  };
}
