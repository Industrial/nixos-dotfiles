# Assay: the fleet firewall stance -- on, and nothing open.
#
# Every published service in this fleet is reached over the tailnet (tailscale0 is a trusted
# interface, owned by features/security/tailscale), so the global allow-lists stay empty and
# any feature that needs a port opens it per-interface. Claims read the evaluated
# networking.firewall options.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./firewall.nix];};
  fw = cfg.networking.firewall;
in
  assay.suite "firewall" {
    firewallEnabled = assay.eq fw.enable true;
    noTCPPortsOpen = assay.eq (nixos.openTCPPorts cfg) [];
    noUDPPortsOpen = assay.eq (nixos.openUDPPorts cfg) [];
    noTCPRangesOpen = assay.eq fw.allowedTCPPortRanges [];
    noUDPRangesOpen = assay.eq fw.allowedUDPPortRanges [];
    # Loopback only, as on an empty system; tailscale0 is added by the tailscale feature.
    trustsNoExtraInterfaces = assay.eq fw.trustedInterfaces nixos.baseline.networking.firewall.trustedInterfaces;
  }
