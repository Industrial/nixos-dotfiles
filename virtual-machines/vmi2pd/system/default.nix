{
  settings,
  inputs,
  ...
}: {
  imports = [
    inputs.microvm.nixosModules.microvm

    # # Monitoring
    # ../../../features/monitoring/prometheus

    # Nix
    ../../../features/nix
    ../../../features/nix/users/trusted-users.nix

    # NixOS
    ../../../features/nixos/boot
    ../../../features/nixos/users

    # Virtual Machine
    ../../../features/virtual-machine/microvm
    ../../../features/virtual-machine/ssh

    {
      networking.hostName = settings.hostname;
      microvm.interfaces = [
        {
          type = "tap";
          id = "vm-i2pd-in";
          mac = "22:00:00:00:00:01";
        }
        {
          type = "tap";
          id = "vm-i2pd-ex";
          mac = "22:00:00:00:00:02";
        }
      ];
      systemd.network.enable = true;
      systemd.network.networks."22-lan".matchConfig.Type = "ether";
      systemd.network.networks."22-lan".networkConfig.Address = ["192.168.8.22/24" "2001:db8::c/64"];
      systemd.network.networks."22-lan".networkConfig.Gateway = "192.168.8.1";
      systemd.network.networks."22-lan".networkConfig.DNS = ["192.168.8.1"];
      systemd.network.networks."22-lan".networkConfig.IPv6AcceptRA = true;
      systemd.network.networks."22-lan".networkConfig.DHCP = "no";
      networking.firewall.enable = true;
      networking.firewall.interfaces.vm-i2pd-in.allowedTCPPorts = [
        # IP2D
        4444
        4447
        # SSH
        22
      ];
      networking.firewall.interfaces.vm-i2pd-in.allowedUDPPorts = [];
      networking.firewall.interfaces.vm-i2pd-ex.allowedTCPPorts = [];
      networking.firewall.interfaces.vm-i2pd-ex.allowedUDPPorts = [];
    }

    # Networking
    ../../../features/network/i2pd

    {
      services.i2pd.ifname = "vm-i2pd-ex";
    }
  ];
}
