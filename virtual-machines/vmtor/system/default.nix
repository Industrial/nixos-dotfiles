{
  settings,
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    # inputs.microvm.nixosModules.microvm

    # # Monitoring
    # ../../../features/monitoring/prometheus

    # Nix
    ../../../features/nix

    # NixOS
    ../../../features/nixos/boot
    ../../../features/nixos/users

    # # Virtual Machine
    ../../../features/virtual-machine/microvm
    ../../../features/virtual-machine/ssh

    {
      networking.hostName = settings.hostname;
      microvm.interfaces = [
        {
          type = "tap";
          id = "vm-tor-in";
          mac = "23:00:00:00:00:01";
        }
        {
          type = "tap";
          id = "vm-tor-ex";
          mac = "23:00:00:00:00:02";
        }
      ];
      # systemd.network.enable = true;
      # # systemd.network.networks."23-lan".matchConfig.Name = "vm-tor-in";
      # systemd.network.networks."23-lan".matchConfig.Type = "ether";
      # systemd.network.networks."23-lan".networkConfig.Address = ["192.168.8.23/24" "2001:db8::d/64"];
      # systemd.network.networks."23-lan".networkConfig.Gateway = "192.168.8.1";
      # systemd.network.networks."23-lan".networkConfig.DNS = ["192.168.8.1"];
      # systemd.network.networks."23-lan".networkConfig.IPv6AcceptRA = true;
      # systemd.network.networks."23-lan".networkConfig.DHCP = "no";

      # networking.firewall.enable = true;
      # networking.firewall.interfaces.vm-tor-in.allowedTCPPorts = [
      #   # Tor "slow" SOCKS port, use for anything but HTTP(S).
      #   9050
      #   # # Tor Control Port.
      #   # 9051
      #   # Tor Privoxy port. Use this for HTTP(S).
      #   8118
      #   # SSH
      #   22
      # ];
      # networking.firewall.interfaces.vm-tor-in.allowedUDPPorts = [];
      # # networking.firewall.interfaces.vm-tor-ex.allowedTCPPorts = [];
      # # networking.firewall.interfaces.vm-tor-ex.allowedUDPPorts = [];
    }
  ];
}
