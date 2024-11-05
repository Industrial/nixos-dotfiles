{inputs, ...}: let
  name = "drakkar";
  system = "x86_64-linux";
  username = "tom";
  version = "24.05";
  settings = {
    inherit system username;
    hostname = "${name}";
    stateVersion = "${version}";
    hostPlatform = {
      inherit system;
    };
    userdir = "/home/${username}";
    useremail = "${username}@${system}.local";
    userfullname = "${username}";
  };
in {
  "${settings.hostname}" = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = {
      inherit inputs settings;
    };
    modules = [
      # Coming automatically pulls from the remote repository and deploys to
      # the local machine.
      inputs.comin.nixosModules.comin
      {
        services.comin = {
          enable = true;
          flakeSubdirectory = "systems/nixos";
          hostname = "${settings.hostname}";
          remotes = [
            {
              name = "origin";
              url = "git@github.com:Industrial/nixos-dotfiles.git";
              branches = {
                main = {
                  name = "main";
                };
              };
            }
          ];
        };
      }

      ../features/cli/appimage-run
      ../features/cli/bat
      ../features/cli/btop
      ../features/cli/c
      ../features/cli/cheatsheet
      ../features/cli/cl
      ../features/cli/create-ssh-key
      ../features/cli/direnv
      ../features/cli/du
      ../features/cli/dust
      ../features/cli/eza
      ../features/cli/fastfetch
      ../features/cli/fd
      ../features/cli/fish
      ../features/cli/fzf
      ../features/cli/g
      ../features/cli/killall
      ../features/cli/l
      ../features/cli/lazygit
      ../features/cli/ll
      ../features/cli/nushell
      ../features/cli/p7zip
      ../features/cli/ripgrep
      ../features/cli/starship
      ../features/cli/unrar
      ../features/cli/unzip
      ../features/communication/discord
      ../features/communication/fractal
      #../features/games/lutris
      #../features/games/path-of-building
      #../features/games/steam
      # ../features/hardware/zsa-keyboard
      #../features/media/invidious
      #../features/media/lidarr
      #../features/media/okular
      #../features/media/prowlarr
      #../features/media/radarr
      #../features/media/readarr
      #../features/media/sonarr
      ../features/media/spotify
      ../features/media/transmission
      ../features/media/vlc
      ## ../features/media/whisparr
      #../features/monitoring/grafana
      #../features/monitoring/homepage-dashboard
      #../features/monitoring/prometheus
      ../features/network/chromium
      ../features/network/firefox
      # ../features/network/i2pd
      ../features/network/syncthing
      # ../features/network/tor
      ../features/network/tor-browser
      ../features/nix
      # ../features/nix/nix-daemon
      ../features/nix/nix-unit
      ../features/nix/nixpkgs
      ../features/nixos/bluetooth
      ../features/nixos/boot
      ../features/nixos/console
      ../features/nixos/docker
      ../features/nixos/fonts
      ../features/nixos/graphics
      ../features/nixos/i18n
      ../features/nixos/networking
      ../features/nixos/security/apparmor
      ../features/nixos/security/yubikey
      ../features/nixos/sound
      # TODO: This specifies disks. Don't do that! Inline it in this config, copy it from the hardware-configuration.nix
      # ../features/nixos/system
      ../features/nixos/time
      ../features/nixos/users
      ../features/nixos/window-manager
      #../features/office/cryptpad
      ../features/office/obsidian
      # ../features/programming/android-tools
      # TODO: Use bun in project flakes, not globally.
      # ../features/programming/bun
      # ../features/programming/deno
      ../features/programming/docker-compose
      # TODO: Use this in project flakes, not globally.
      # ../features/programming/edgedb
      ../features/programming/git
      ../features/programming/haskell
      #../features/programming/gitkraken
      #../features/programming/glogg
      # ../features/programming/insomnia
      #../features/programming/meld
      # ../features/programming/neovim
      ../features/programming/nixd
      #../features/programming/nodejs
      #../features/programming/python
      ../features/programming/vscode
      ../features/security/veracrypt
      ../features/security/yubikey-manager
      ../features/security/keepassxc
      # ../features/virtual-machine/base
      # ../features/virtual-machine/kubernetes/master
      # ../features/virtual-machine/kubernetes/node
      # ../features/virtual-machine/microvm
      # ../features/virtual-machine/ssh
      ../features/virtual-machine/virtualbox
      ../features/window-manager/alacritty
      ../features/window-manager/dwm
      #../features/window-manager/gnome
      #../features/window-manager/hyper
      ../features/window-manager/slock
      inputs.stylix.nixosModules.stylix
      ../features/window-manager/stylix
      ../features/window-manager/xfce
      #../features/window-manager/xmonad
      ../features/window-manager/xsel
      ../features/window-manager/xclip

      {
        boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "uas" "sd_mod" "rtsx_pci_sdmmc"];
        boot.initrd.kernelModules = [];
        boot.kernelModules = ["kvm-intel"];
        boot.extraModulePackages = [];

        # /boot
        fileSystems."/boot" = {
          device = "/dev/disk/by-uuid/A32E-E364";
          fsType = "vfat";
          options = ["fmask=0077" "dmask=0077"];
        };

        # /
        boot.initrd.luks.devices."luks-b72e827b-19c5-43a4-8a20-d9cd0dd7f0b5".device = "/dev/disk/by-uuid/b72e827b-19c5-43a4-8a20-d9cd0dd7f0b5";
        fileSystems."/" = {
          device = "/dev/disk/by-uuid/7aca8703-57c7-4805-aadb-d17c68b28c81";
          fsType = "ext4";
        };

        # swap
        boot.initrd.luks.devices."luks-2c489d7f-4cfb-4c08-994e-96212646fc55".device = "/dev/disk/by-uuid/2c489d7f-4cfb-4c08-994e-96212646fc55";
        swapDevices = [
          {
            device = "/dev/disk/by-uuid/d7a6a603-e5e3-401f-8237-99bc29182994";
          }
        ];
      }
    ];
  };
}
