{
  settings,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./graphics
    ./hardware-configuration.nix
    inputs.microvm.nixosModules.host

    # CLI
    ../../../features/cli/ansifilter
    ../../../features/cli/appimage-run
    ../../../features/cli/bat
    ../../../features/cli/btop
    ../../../features/cli/direnv
    ../../../features/cli/e2fsprogs
    ../../../features/cli/eza
    ../../../features/cli/fd
    ../../../features/cli/fish
    ../../../features/cli/fzf
    ../../../features/cli/gh
    ../../../features/cli/lazygit
    ../../../features/cli/neofetch
    ../../../features/cli/p7zip
    ../../../features/cli/ranger
    ../../../features/cli/ripgrep
    ../../../features/cli/starship
    ../../../features/cli/unrar
    ../../../features/cli/unzip
    ../../../features/cli/zellij

    # Communication
    ../../../features/communication/discord

    # Crypto
    ../../../features/crypto/monero

    # Filesystems
    ../../../features/filesystems/gparted

    # Games
    ../../../features/games/lutris
    ../../../features/games/path-of-building
    ../../../features/games/steam

    # Hardware
    ../../../features/hardware/zsa-keyboard

    # Media
    ../../../features/media/invidious
    ../../../features/media/lxqt-pavucontrol-qt
    ../../../features/media/lxqt-screengrab
    ../../../features/media/okular
    ../../../features/media/spotify
    ../../../features/media/vlc

    # Monitoring
    ../../../features/monitoring/grafana
    ../../../features/monitoring/homepage-dashboard
    ../../../features/monitoring/lxqt-qps
    ../../../features/monitoring/prometheus

    # Network
    ../../../features/network/chromium
    ../../../features/network/firefox
    ../../../features/network/i2pd
    ../../../features/network/nginx
    ../../../features/network/syncthing
    ../../../features/network/tor
    ../../../features/network/tor-browser
    ../../../features/network/transmission

    # Nix
    ../../../features/nix
    ../../../features/nix/nix-unit
    ../../../features/nix/nixpkgs
    ../../../features/nix/shell

    # NixOS
    # ../../../features/nixos/docker
    # ../../../features/nixos/networking
    # ../../../features/nixos/security/apparmor
    # ../../../features/nixos/security/clamav
    ../../../features/nixos/bluetooth
    ../../../features/nixos/boot
    ../../../features/nixos/console
    ../../../features/nixos/fonts
    ../../../features/nixos/i18n
    ../../../features/nixos/printing
    ../../../features/nixos/security
    ../../../features/nixos/security/yubikey
    ../../../features/nixos/sound
    ../../../features/nixos/system
    ../../../features/nixos/time
    ../../../features/nixos/users
    ../../../features/nixos/window-manager

    # Office
    ../../../features/office/cryptpad
    ../../../features/office/evince
    ../../../features/office/lxqt-archiver
    ../../../features/office/lxqt-pcmanfm-qt
    ../../../features/office/obsidian

    # Programming
    ../../../features/programming/android-tools
    ../../../features/programming/docker-compose
    ../../../features/programming/git
    ../../../features/programming/gitkraken
    ../../../features/programming/neovim
    ../../../features/programming/nixd
    ../../../features/programming/nodejs
    ../../../features/programming/ollama
    ../../../features/programming/sqlite
    ../../../features/programming/vscode
    inputs.nixvim.nixosModules.nixvim

    # Security
    # ../../../features/security/vaultwarden
    ../../../features/security/veracrypt
    ../../../features/security/yubikey-manager
    ../../../features/security/bitwarden

    # Window Manager
    # ../../../features/window-manager/dwm
    # ../../../features/window-manager/xmonad
    ../../../features/window-manager/alacritty
    ../../../features/window-manager/hyper
    ../../../features/window-manager/stylix
    ../../../features/window-manager/xfce
    inputs.stylix.nixosModules.stylix

    {
      # networking.networkmanager.enable = true;
      networking.hostName = settings.hostname;
      networking.useNetworkd = true;
      systemd.network.enable = true;

      # Simple Configuration (Static IP Address)
      systemd.network.networks."10-lan".matchConfig.Name = ["enp16s0" "vm-*"];
      systemd.network.networks."10-lan".networkConfig.Bridge = "br0";
      systemd.network.netdevs."br0".netdevConfig.Name = "br0";
      systemd.network.netdevs."br0".netdevConfig.Kind = "bridge";
      systemd.network.networks."10-lan-bridge".matchConfig.Name = "br0";
      systemd.network.networks."10-lan-bridge".networkConfig.Address = ["192.168.8.20/24" "2001:db8::a/64"];
      systemd.network.networks."10-lan-bridge".networkConfig.Gateway = "192.168.8.1";
      systemd.network.networks."10-lan-bridge".networkConfig.DNS = "192.168.8.1";
      systemd.network.networks."10-lan-bridge".networkConfig.IPv6AcceptRA = true;
      systemd.network.networks."10-lan-bridge".linkConfig.RequiredForOnline = "routable";

      # microvm.vms = let
      #   vmTorSettings = import ../../../virtual-machines/vmtor/settings.nix;
      #   vmTorPkgs = import inputs.nixpkgs {
      #     stateVersion = vmTorSettings.stateVersion;
      #     system = vmTorSettings.system;
      #     hostPlatform = vmTorSettings.system;
      #     config = {
      #       allowUnfree = true;
      #       allowBroken = false;
      #     };
      #   };
      # in {
      #   vmtor = {
      #     pkgs = vmTorPkgs;
      #     specialArgs = {
      #       inherit inputs;
      #       settings = vmTorSettings;
      #     };
      #     config = {
      #       imports = [
      #         {
      #           system.stateVersion = vmTorSettings.stateVersion;
      #           users.users.root.password = "";
      #           # Show the output of this command in `journalctl -u microvm@vmtor.service`;
      #           programs.bash.loginShellInit = "systemctl status sshd";
      #           services.getty.autologinUser = "root";
      #           services.openssh.enable = true;
      #           services.openssh.settings.PasswordAuthentication = true;
      #           services.openssh.settings.PermitRootLogin = "yes";
      #           systemd.network.enable = true;
      #           systemd.network.networks."23-lan".matchConfig.Type = "ether";
      #           systemd.network.networks."23-lan".networkConfig.Address = ["192.168.8.23/24" "2001:db8::d/64"];
      #           systemd.network.networks."23-lan".networkConfig.DHCP = "no";
      #           systemd.network.networks."23-lan".networkConfig.DNS = ["192.168.8.1"];
      #           systemd.network.networks."23-lan".networkConfig.Gateway = "192.168.8.1";
      #           systemd.network.networks."23-lan".networkConfig.IPv6AcceptRA = true;
      #           microvm = {
      #             volumes = [
      #               {
      #                 mountPoint = "/var";
      #                 image = "var.img";
      #                 size = 256;
      #               }
      #             ];
      #             shares = [
      #               {
      #                 # use "virtiofs" for MicroVMs that are started by systemd
      #                 proto = "9p";
      #                 tag = "ro-store";
      #                 # a host's /nix/store will be picked up so that no
      #                 # squashfs/erofs will be built for it.
      #                 source = "/nix/store";
      #                 mountPoint = "/nix/.ro-store";
      #               }
      #             ];
      #             interfaces = [
      #               {
      #                 type = "tap";
      #                 id = "vm-tor-in";
      #                 mac = "23:00:00:00:00:01";
      #               }
      #               {
      #                 type = "tap";
      #                 id = "vm-tor-ex";
      #                 mac = "23:00:00:00:00:02";
      #               }
      #             ];
      #             hypervisor = "qemu";
      #             socket = "control.socket";
      #           };
      #         }
      #       ];
      #     };
      #   };
      # };
    }
  ];
}
