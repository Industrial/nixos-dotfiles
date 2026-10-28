# Colocated suite: keepalived VRRP failover.
#
# This module is option-gated, so the suite exercises both states: disabled must emit no
# service at all, and enabled must derive the VRRP role from the priority. Getting the
# MASTER/BACKUP split wrong gives two masters and a split-brain VIP, which is the failure this
# pins down.
let
  assay = import ./../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  eval = settings:
    (nixpkgsLib.evalModules {
      modules = [
        ./default.nix
        {
          _module.args.pkgs = import <nixpkgs> {};
          features.keepalived = settings;
        }
        # Minimal stand-ins for the option trees this module writes into.
        {
          options.environment.systemPackages = nixpkgsLib.mkOption {
            type = nixpkgsLib.types.listOf nixpkgsLib.types.unspecified;
            default = [];
          };
          options.services.keepalived = nixpkgsLib.mkOption {
            type = nixpkgsLib.types.attrsOf nixpkgsLib.types.unspecified;
            default = {};
          };
          options.networking.firewall.extraCommands = nixpkgsLib.mkOption {
            type = nixpkgsLib.types.lines;
            default = "";
          };
        }
      ];
    })
    .config;

  disabled = eval {enable = false;};
  backup = eval {
    enable = true;
    virtualIp = "192.168.1.100";
    interface = "enp0s3";
  };
  master = eval {
    enable = true;
    virtualIp = "192.168.1.100";
    interface = "enp0s3";
    priority = 150;
  };
in
  assay.suite "keepalived" {
    # Disabled must be inert — this module is imported by hosts that do not want a VIP.
    disabledEmitsNoService = assay.eq (disabled.services.keepalived == {}) true;
    disabledInstallsNothing = assay.eq disabled.environment.systemPackages [];
    disabledOpensNoFirewallHole = assay.eq disabled.networking.firewall.extraCommands "";

    enabledStartsService = assay.eq backup.services.keepalived.enable true;

    # Role is derived from priority: >= 150 is MASTER, anything lower is BACKUP. Two MASTERs
    # on one VRRP group means a split-brain VIP.
    defaultPriorityIsBackup = assay.eq backup.services.keepalived.vrrpInstances.FLEET_VIP.state "BACKUP";
    highPriorityIsMaster = assay.eq master.services.keepalived.vrrpInstances.FLEET_VIP.state "MASTER";
    defaultPriorityIsOneHundred = assay.eq backup.services.keepalived.vrrpInstances.FLEET_VIP.priority 100;

    # Peers must agree on the router id or they will not see each other.
    defaultRouterIdIs51 = assay.eq backup.services.keepalived.vrrpInstances.FLEET_VIP.virtualRouterId 51;

    # The VIP is declared with a prefix length; a bare address would be rejected by keepalived.
    vipCarriesPrefix = assay.eq (builtins.head backup.services.keepalived.vrrpInstances.FLEET_VIP.virtualIps).addr "192.168.1.100/24";

    # VRRP is its own IP protocol and needs an explicit firewall hole.
    opensVrrpInFirewall = assay.eq (builtins.match ".*-p vrrp -j ACCEPT.*" backup.networking.firewall.extraCommands != null) true;

    # Failover is driven by a health check, not just by liveness of the host.
    tracksServiceHealth = assay.eq (backup.services.keepalived.vrrpScripts ? chk_services) true;
    healthCheckInterval = assay.eq backup.services.keepalived.vrrpScripts.chk_services.interval 2;
  }
