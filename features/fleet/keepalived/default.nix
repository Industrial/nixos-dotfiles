# Keepalived VRRP failover for fleet services.
# Provides automatic IP failover between hosts (e.g., mimir <-> muninn).
#
# Usage: Import this module and set the options in the host config:
#   features.keepalived.virtualIp = "192.168.1.100";
#   features.keepalived.interface = "enp0s3";
#   features.keepalived.priority = 100;  # Higher = preferred master
#   features.keepalived.routerId = 51;   # Must match across VRRP peers
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.features.keepalived;
in {
  options.features.keepalived = {
    enable = mkEnableOption "keepalived VRRP failover";

    virtualIp = mkOption {
      type = types.str;
      description = "Virtual IP address that floats between VRRP peers";
      example = "192.168.1.100";
    };

    interface = mkOption {
      type = types.str;
      description = "Network interface for VRRP communication and VIP";
      example = "enp0s3";
    };

    priority = mkOption {
      type = types.int;
      default = 100;
      description = "VRRP priority (higher = preferred master). Use 150 for primary, 100 for backup.";
    };

    routerId = mkOption {
      type = types.int;
      default = 51;
      description = "VRRP router ID (must be same across all peers in the group)";
    };

    authPass = mkOption {
      type = types.str;
      default = "fleetvrrp";
      description = "VRRP authentication password (shared across peers)";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [pkgs.keepalived];

    services.keepalived = {
      enable = true;

      vrrpInstances.FLEET_VIP = {
        interface = cfg.interface;
        state =
          if cfg.priority >= 150
          then "MASTER"
          else "BACKUP";
        virtualRouterId = cfg.routerId;
        priority = cfg.priority;

        virtualIps = [
          {addr = "${cfg.virtualIp}/24";}
        ];

        extraConfig = ''
          advert_int 1
          authentication {
            auth_type PASS
            auth_pass ${cfg.authPass}
          }
          track_script {
            chk_services
          }
        '';
      };

      vrrpScripts.chk_services = {
        script = "${pkgs.writeShellScript "check-services" ''
          # Check if critical services are running
          ${pkgs.systemd}/bin/systemctl is-active --quiet prometheus.service || exit 1
          ${pkgs.systemd}/bin/systemctl is-active --quiet grafana.service || exit 1
          exit 0
        ''}";
        interval = 2;
        weight = 2;
        fall = 2;
        rise = 2;
      };
    };

    # Allow VRRP protocol through firewall
    networking.firewall.extraCommands = ''
      iptables -A INPUT -p vrrp -j ACCEPT
    '';
  };
}
