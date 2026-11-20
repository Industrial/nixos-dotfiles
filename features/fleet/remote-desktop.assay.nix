# Assay: fleet remote desktop client.
#
# The client feature is deliberately inert on the network: it installs the
# RustDesk binary and nothing else. Reachability is owned by
# features/security/tailscale (trustedInterfaces) and the server side lives in
# remote-desktop-relay.nix, so a port opened here would be a scope leak.
#
# Claims read the evaluated NixOS config, not the module's text: a port opened
# through mkMerge, a helper or an import fails them just the same, and a comment
# naming the server can no longer fail them.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./remote-desktop.nix];};
in
  assay.suite "remote-desktop" {
    installsClient = assay.eq (nixos.hasPackage cfg "rustdesk") true;

    # The signal/relay servers belong on mimir only, never in the all-host feature.
    noServerHere = assay.eq cfg.services.rustdesk-server.enable false;

    # Must not publish ports; the tailnet trusted interface is the only path.
    noTCPPortsOpened = assay.eq (nixos.openTCPPorts cfg) (nixos.openTCPPorts nixos.baseline);
    noUDPPortsOpened = assay.eq (nixos.openUDPPorts cfg) (nixos.openUDPPorts nixos.baseline);
    noTCPRangesOpened = assay.eq cfg.networking.firewall.allowedTCPPortRanges [];
  }
