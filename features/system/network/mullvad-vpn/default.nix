# VPN Client.
{
  config,
  pkgs,
  settings,
  ...
}: let
  # https://mullvad.net/en/help/faq#39
  # TCP Ports
  # 80: HTTP
  # 443: HTTPS
  # 1401: (Add description here)
  tcpPorts = [
    80 # HTTP
    443 # HTTPS
    1401 # (Add description here)
  ];

  # UDP Ports
  # 53: DNS
  # 1194 to 1197: (Add description here)
  # 1300 to 1303: (Add description here)
  # 1400: (Add description here)
  udpPorts = [
    53 # DNS
    1194 # (Add description here)
    1195 # (Add description here)
    1196 # (Add description here)
    1197 # (Add description here)
    1300 # (Add description here)
    1301 # (Add description here)
    1302 # (Add description here)
    1303 # (Add description here)
    1400 # (Add description here)
  ];

  nameservers = [
    "194.242.2.2#dns.mullvad.net"
    "194.242.2.3#adblock.dns.mullvad.net"
    "194.242.2.4#base.dns.mullvad.net"
    "194.242.2.5#extended.dns.mullvad.net"
    "194.242.2.9#all.dns.mullvad.net"
  ];
in {
  networking.nameservers = nameservers;
  networking.firewall.checkReversePath = "loose";
  networking.firewall.allowedTCPPorts = tcpPorts;
  networking.firewall.allowedUDPPorts = udpPorts;

  networking.wireguard.enable = true;
  networking.iproute2.enable = true;

  services.mullvad-vpn.enable = true;

  services.mullvad-vpn.package = pkgs.mullvad-vpn;
  environment.systemPackages = with pkgs; [
    mullvad-vpn
  ];

  # Connection Tracking Kernel Module
  boot.kernelModules = ["nf_conntrack"];

  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.nftables.ruleset = ''
    table inet firewall {
      chain inbound {
        type filter hook input priority 0;
        policy drop;

        iifname lo accept;

        tcp dport { ${builtins.concatStringsSep ", " ((map (port: toString port) config.networking.firewall.allowedTCPPorts) ++ (map (range: "${toString range.from}-${toString range.to}") config.networking.firewall.allowedTCPPortRanges))} } accept
        udp dport { ${builtins.concatStringsSep ", " ((map (port: toString port) config.networking.firewall.allowedUDPPorts) ++ (map (range: "${toString range.from}-${toString range.to}") config.networking.firewall.allowedUDPPortRanges))} } accept

        ct state {established, related} accept;
      }

      chain forward {
        type filter hook forward priority 0; policy drop;
      }

      chain outbound {
        type filter hook output priority 0; policy accept;
      }
    }
  '';

  services.resolved.enable = true;
  services.resolved.dnssec = "false";
  services.resolved.domains = ["~."];
  services.resolved.fallbackDns = nameservers;
  services.resolved.extraConfig = ''
    DNSSEC=no
    DNSOverTLS=yes
  '';
}
