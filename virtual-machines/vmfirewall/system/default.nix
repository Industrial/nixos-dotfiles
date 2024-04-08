{
  settings,
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.microvm.nixosModules.microvm

    # # Monitoring
    # ../../../features/monitoring/prometheus

    # Nix
    ../../../features/nix
    ../../../features/nix/shell

    # NixOS
    ../../../features/nixos/boot
    ../../../features/nixos/users

    # Virtual Machine
    ../../../features/virtual-machine/microvm
    ../../../features/virtual-machine/ssh

    {
      systemd.network.enable = true;
      # networking.firewall.enable = false;ether
      networking.hostName = settings.hostname;

      # microvm.interfaces = [
      #   # InternalInterface
      #   {
      #     type = "tap";
      #     id = "vm-firewall-in";
      #     mac = "21:00:00:00:00:01";
      #   }
      #   # ExternalInterface
      #   {
      #     type = "tap";
      #     id = "vm-firewall-ex";
      #     mac = "21:00:00:00:00:02";
      #   }
      # ];

      # # Inbound Traffic
      # systemd.network.networks."21-lan".matchConfig.Type = "ether";
      # # Use the MAC address of the firewall's InternalInterface
      # systemd.network.networks."21-lan".matchConfig.MACAddress = "21:00:00:00:00:01";
      # systemd.network.networks."21-lan".networkConfig.Address = ["192.168.8.21/24" "2001:db8::b/64"];
      # systemd.network.networks."21-lan".networkConfig.Gateway = "192.168.8.1";
      # systemd.network.networks."21-lan".networkConfig.DNS = ["192.168.8.1"];
      # systemd.network.networks."21-lan".networkConfig.IPv6AcceptRA = true;
      # systemd.network.networks."21-lan".networkConfig.DHCP = "no";
      # networking.firewall.interfaces.vm-firewall-in.allowedTCPPorts = [
      #   # Tor
      #   9050
      #   9051
      #   # IP2D
      #   4444
      #   4447
      #   # SSH
      #   22
      # ];
      # networking.firewall.interfaces.vm-firewall-in.allowedUDPPorts = [];

      # # Outbound Traffic
      # # Route all traffic through the ExternalInterface.
      # networking.defaultGateway.address = "192.168.8.1";
      # networking.defaultGateway.interface = "vm-firewall-ex";
      # networking.defaultGateway6.address = "2001::db8::1";
      # networking.defaultGateway6.interface = "vm-firewall-ex";

      # networking.firewall.interfaces.vm-firewall-ex.allowedTCPPorts = [];
      # networking.firewall.interfaces.vm-firewall-ex.allowedUDPPorts = [];
    }
  ];
}
