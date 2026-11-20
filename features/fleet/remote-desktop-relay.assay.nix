# Assay: fleet remote desktop relay (mimir).
#
# The load-bearing claim is that no port is published. Tailnet reachability comes
# from features/security/tailscale marking tailscale0 trusted; flipping
# openFirewall would publish 21115-21119 on every interface instead, which
# would silently undo the "inside tailscale" requirement.
#
# Claims read the evaluated config, so they hold however the module is written — and
# a setting upstream removed (relayIP) is an eval error here, not a regex to keep.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./remote-desktop-relay.nix];};
  rd = cfg.services.rustdesk-server;
in
  assay.suite "remote-desktop-relay" {
    enablesServer = assay.eq rd.enable true;
    enablesSignal = assay.eq rd.signal.enable true;
    enablesRelay = assay.eq rd.relay.enable true;

    # Never publish the ports beyond the tailnet.
    firewallStaysClosed = assay.eq rd.openFirewall false;
    noTCPPortsOpened = assay.eq (nixos.openTCPPorts cfg) (nixos.openTCPPorts nixos.baseline);
    noUDPPortsOpened = assay.eq (nixos.openUDPPorts cfg) (nixos.openUDPPorts nixos.baseline);

    # Clients need an advertised relay endpoint; empty relayHosts makes hbbs
    # start with a bare `--relay-servers` argument.
    declaresRelayHost = assay.eq rd.signal.relayHosts ["mimir"];
  }
