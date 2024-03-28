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
          id = "vm-tor-in";
          mac = "02:00:00:00:00:01";
        }
        {
          type = "tap";
          id = "vm-tor-out";
          mac = "02:00:00:00:00:02";
        }
      ];
      systemd.network.enable = true;
      systemd.network.networks."23-lan".matchConfig.Type = "ether";
      systemd.network.networks."23-lan".networkConfig.Address = ["192.168.8.23/24" "2001:db8::d/64"];
      systemd.network.networks."23-lan".networkConfig.Gateway = "192.168.8.1";
      systemd.network.networks."23-lan".networkConfig.DNS = ["192.168.8.1"];
      systemd.network.networks."23-lan".networkConfig.IPv6AcceptRA = true;
      systemd.network.networks."23-lan".networkConfig.DHCP = "no";
      # Send all traffic from the vm-tor-out interface to the vmfirewall virtual machine.
      # systemd.network.networks."20-lan".networkConfig.PostUp = "ip route add default via 192.168.8.21 dev vm-tor-out";
      services.openssh.enable = true;
      services.openssh.settings.PermitRootLogin = "yes";
      services.openssh.settings.PasswordAuthentication = true;
      networking.firewall.enable = true;
      networking.firewall.allowedTCPPorts = [9050 9051];
      networking.firewall.allowedUDPPorts = [];
      networking.nat.enable = true;
      networking.nat.internalInterfaces = ["vm-tor-in"];
      networking.nat.externalInterface = "vm-tor-out";
      networking.nat.forwardPorts = [];
    }

    {
      services.tor = {
        enable = true;
        client = {
          enable = true;
          # proxy = "vm-tor-in";
          socksListenAddress = {
            addr = "127.0.0.1";
            port = 9051;
          };
          # dns = {
          #   enable = true;
          # };
        };
        # Disable the relay. We want to only be a client.
        relay = {
          enable = false;
        };
        settings = {
          OutboundBindAddress = "vm-tor-out";
        };
      };
    }
  ];
}
