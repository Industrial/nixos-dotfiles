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
    ../../../features/nix/shell

    # NixOS
    ../../../features/nixos/boot
    # ../../../features/nixos/console
    # ../../../features/nixos/fonts
    # ../../../features/nixos/i18n
    ../../../features/nixos/nix
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
          id = "vm-i2pd-in";
          mac = "02:00:00:00:00:01";
        }
        {
          type = "tap";
          id = "vm-i2pd-out";
          mac = "02:00:00:00:00:02";
        }
      ];
      systemd.network.enable = true;
      systemd.network.networks."22-lan".matchConfig.Type = "ether";
      systemd.network.networks."22-lan".networkConfig.Address = ["192.168.8.22/24" "2001:db8::c/64"];
      systemd.network.networks."22-lan".networkConfig.Gateway = "192.168.8.1";
      systemd.network.networks."22-lan".networkConfig.DNS = ["192.168.8.1"];
      systemd.network.networks."22-lan".networkConfig.IPv6AcceptRA = true;
      systemd.network.networks."22-lan".networkConfig.DHCP = "no";
      # # Send all traffic from the vm-i2pd-out interface to the vmfirewall virtual machine.
      # systemd.network.networks."20-lan".networkConfig.PostUp = "ip route add default via 192.168.8.21 dev vm-i2pd-out";
      services.openssh.enable = true;
      services.openssh.settings.PermitRootLogin = "yes";
      services.openssh.settings.PasswordAuthentication = true;
      networking.firewall.enable = true;
      networking.firewall.allowedTCPPorts = [4444 4447 22];
      networking.firewall.allowedUDPPorts = [];
      networking.nat.enable = true;
      networking.nat.internalInterfaces = ["vm-i2pd-in"];
      networking.nat.externalInterface = "vm-i2pd-out";
      networking.nat.forwardPorts = [];
    }

    {
      services.i2pd = {
        enable = true;
        enableIPv4 = false;
        enableIPv6 = true;
        ifname = "vm-i2pd-out";
        # proto = {
        #   # httpProxy = {
        #   #   enable = true;
        #   # };
        #   socksProxy = {
        #     enable = true;
        #     address = "127.0.0.1";
        #   };
        # };
        # # app = {
        # #   enable = true;
        # #   httpProxy = "vm-i2pd-in";
        # #   socksProxy = "vm-i2pd-out";
        # # };
      };
    }
  ];
}
