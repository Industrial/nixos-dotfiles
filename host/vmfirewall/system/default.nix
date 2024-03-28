{
  settings,
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.microvm.nixosModules.microvm

    # CLI
    # ../../../features/cli/bat
    ../../../features/cli/btop
    # ../../../features/cli/direnv
    # ../../../features/cli/e2fsprogs
    # ../../../features/cli/eza
    # ../../../features/cli/fd
    # ../../../features/cli/fish
    # ../../../features/cli/fzf
    # ../../../features/cli/gh
    # ../../../features/cli/neofetch
    # ../../../features/cli/p7zip
    # ../../../features/cli/ranger
    # ../../../features/cli/ripgrep
    # ../../../features/cli/starship
    # ../../../features/cli/unrar
    # ../../../features/cli/zellij

    # # Monitoring
    # ../../../features/monitoring/prometheus

    # Nix
    ../../../features/nix
    ../../../features/nix/shell

    # NixOS
    ../../../features/nixos/boot
    # ../../../features/nixos/console
    # ../../../features/nixos/fonts
    # ../../../features/nixos/i18n
    # ../../../features/nixos/security
    # ../../../features/nixos/system
    # ../../../features/nixos/time
    ../../../features/nixos/users

    {
      users.users.root.password = "";
      microvm = {
        volumes = [
          {
            mountPoint = "/var";
            image = "var.img";
            size = 256;
          }
        ];
        shares = [
          {
            # use "virtiofs" for MicroVMs that are started by systemd
            proto = "9p";
            tag = "ro-store";
            # a host's /nix/store will be picked up so that no
            # squashfs/erofs will be built for it.
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }
        ];
        hypervisor = "qemu";
        socket = "control.socket";
      };
    }

    {
      services.openssh.enable = true;
      services.openssh.settings.PermitRootLogin = "yes";
      services.openssh.settings.PasswordAuthentication = true;
    }

    {
      networking.hostName = settings.hostname;
      microvm.interfaces = [
        {
          type = "tap";
          id = "vm-firewall-in";
          mac = "02:00:00:00:00:01";
        }
        {
          type = "tap";
          id = "vm-firewall-out";
          mac = "02:00:00:00:00:02";
        }
      ];
      systemd.network.enable = true;
      systemd.network.networks."21-lan".matchConfig.Type = "ether";
      systemd.network.networks."21-lan".networkConfig.Address = ["192.168.8.21/24" "2001:db8::b/64"];
      systemd.network.networks."21-lan".networkConfig.Gateway = "192.168.8.1";
      systemd.network.networks."21-lan".networkConfig.DNS = ["192.168.8.1"];
      systemd.network.networks."21-lan".networkConfig.IPv6AcceptRA = true;
      systemd.network.networks."21-lan".networkConfig.DHCP = "no";
      services.openssh.enable = true;
      services.openssh.settings.PermitRootLogin = "yes";
      services.openssh.settings.PasswordAuthentication = true;
      networking.firewall.enable = true;
      networking.firewall.allowedTCPPorts = [9050 4444 22];
      networking.firewall.allowedUDPPorts = [];
      networking.nat.enable = true;
      networking.nat.internalInterfaces = ["vm-firewall-in"];
      networking.nat.externalInterface = "vm-firewall-out";
      networking.nat.forwardPorts = [
        # Forward Tor traffic
        {
          destination = "vmtor:9050";
          sourcePort = 9050;
        }
        # Forward I2PD traffic
        {
          destination = "vmi2pd:4444";
          sourcePort = 4444;
        }
      ];
    }
  ];
}
