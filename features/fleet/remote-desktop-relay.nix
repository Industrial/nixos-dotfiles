# RustDesk signal (hbbs) + relay (hbbr) for the fleet — mimir only.
#
# mimir is the always-on file server, so it holds the rendezvous point that the
# other three hosts (drakkar, huginn, muninn) register against. Clients come
# from features/fleet/remote-desktop.nix.
#
# openFirewall stays false on purpose. features/security/tailscale already sets
# networking.firewall.trustedInterfaces = ["tailscale0"], which accepts fleet
# traffic on 21115-21119/tcp and 21116/udp over the tailnet. Setting
# openFirewall would additionally publish those ports on every other
# interface, including the public one — the opposite of what we want.
#
# Note: services.rustdesk-server.relayIP was removed upstream in favour of
# signal.relayHosts; the assay guards against it creeping back in.
{
  services.rustdesk-server = {
    enable = true;

    # Tailnet reachability comes from trustedInterfaces, not from here.
    openFirewall = false;

    signal = {
      enable = true;
      # Handed to clients by hbbs as the relay endpoint. MagicDNS short name.
      relayHosts = ["mimir"];
    };

    relay = {
      enable = true;
    };
  };
}
