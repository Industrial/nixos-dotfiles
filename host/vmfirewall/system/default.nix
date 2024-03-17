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
    ../../../features/cli/bat
    ../../../features/cli/btop
    ../../../features/cli/direnv
    ../../../features/cli/e2fsprogs
    ../../../features/cli/eza
    ../../../features/cli/fd
    ../../../features/cli/fish
    ../../../features/cli/fzf
    ../../../features/cli/gh
    ../../../features/cli/neofetch
    ../../../features/cli/p7zip
    ../../../features/cli/ranger
    ../../../features/cli/ripgrep
    ../../../features/cli/starship
    ../../../features/cli/unrar
    ../../../features/cli/zellij

    # Monitoring
    ../../../features/monitoring/prometheus

    # Nix
    ../../../features/nix/shell

    # NixOS
    ../../../features/nixos/boot
    ../../../features/nixos/console
    ../../../features/nixos/fonts
    ../../../features/nixos/i18n
    ../../../features/nixos/nix
    ../../../features/nixos/security
    ../../../features/nixos/system
    ../../../features/nixos/time
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
      # networking.useNetworkD = true;
      # networking.interfaces.eth0.ipv4.addresses = [
      #   {
      #     address = "192.168.3.1";
      #     prefixLength = 24;
      #   }
      # ];
      # networking.interfaces.eth1.ipv4.addresses = [
      #   {
      #     address = "192.168.4.1";
      #     prefixLength = 24;
      #   }
      # ];
      # networking.firewall.enable = true;
      # networking.firewall.interfaces.eth1.allowedTCPPorts = [22 443];
      # networking.firewall.interfaces.eth1.allowedUDPPorts = [];

      networking.hostName = settings.hostname;
      microvm.interfaces = [
        {
          type = "tap";
          id = "vm-firewall";
          mac = "02:00:00:00:00:01";
        }
      ];
      systemd.network.enable = true;
      systemd.network.networks."20-lan".matchConfig.Type = "ether";
      systemd.network.networks."20-lan".networkConfig.Address = ["192.168.8.22/24" "2001:db8::b/64"];
      systemd.network.networks."20-lan".networkConfig.Gateway = "192.168.8.1";
      systemd.network.networks."20-lan".networkConfig.DNS = ["192.168.8.1"];
      systemd.network.networks."20-lan".networkConfig.IPv6AcceptRA = true;
      systemd.network.networks."20-lan".networkConfig.DHCP = "no";
      services.openssh.enable = true;
      services.openssh.settings.PermitRootLogin = "yes";
      services.openssh.settings.PasswordAuthentication = true;
    }
  ];
}
