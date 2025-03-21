{inputs, ...}: let
  name = "gandi_nixos_001";
  system = "x86_64-linux";
  username = "tom";
  version = "24.11";
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
      # ../features/ai/n8n
      # ../features/ai/ollama
      inputs.comin.nixosModules.comin
      ../features/ci/comin
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
      ../features/cli/gpg
      ../features/cli/jq
      ../features/cli/killall
      ../features/cli/l
      ../features/cli/lazygit
      ../features/cli/ll
      ../features/cli/p
      ../features/cli/p7zip
      ../features/cli/ripgrep
      ../features/cli/starship
      ../features/cli/unrar
      ../features/cli/unzip
      ../features/cli/zellij
      # ../features/communication/discord
      # ../features/communication/fractal
      # ../features/communication/teams
      # ../features/communication/telegram
      # ../features/communication/weechat
      # ../features/crypto/monero
      # ../features/games/lutris
      # # ../features/games/path-of-building
      # # ../features/games/steam
      # ../features/games/wowup
      # ../features/media/invidious
      # ../features/media/jellyfin
      # ../features/media/lidarr
      # ../features/media/prowlarr
      # ../features/media/radarr
      # ../features/media/readarr
      # ../features/media/sonarr
      # ../features/media/spotify
      # ../features/media/tiny-tiny-rss
      # ../features/media/transmission
      # ../features/media/vlc
      # ../features/media/whisparr
      # ../features/monitoring/grafana
      # ../features/monitoring/homepage-dashboard
      # ../features/monitoring/prometheus
      # ../features/network/chromium
      # ../features/network/firefox
      # #../features/network/i2pd
      # ../features/network/searx
      # ../features/network/ssh
      # ../features/network/syncthing
      # #../features/network/tor
      # #../features/network/tor-browser
      ../features/nix
      # # This is for Darwin only.
      # #../features/nix/nix-daemon
      ../features/nix/nixpkgs
      # ../features/nixos/bluetooth
      # ../features/nixos/boot
      # ../features/nixos/docker
      # ../features/nixos/fonts
      # ../features/nixos/graphics
      # ../features/nixos/networking
      # ../features/nixos/networking/dns.nix
      # ../features/nixos/networking/firewall.nix
      ../features/nixos/security/no-defaults
      # ../features/nixos/security/sudo
      # ../features/nixos/sound
      # ../features/nixos/users
      # ../features/nixos/window-manager
      # ../features/office/obsidian
      # ../features/programming/bun
      ../features/programming/devenv
      # ../features/programming/docker-compose
      ../features/programming/git
      # ../features/programming/gitkraken
      # ../features/programming/glogg
      # ../features/programming/insomnia
      # ../features/programming/meld
      # ../features/programming/node
      # ../features/programming/python
      # ../features/programming/vscode
      # ../features/security/keepassxc
      # ../features/security/tailscale
      # ../features/security/veracrypt
      # #../features/security/yubikey-manager
      # #../features/virtual-machine/base
      # #../features/virtual-machine/kubernetes/k3s
      # #../features/virtual-machine/kubernetes/master
      # #../features/virtual-machine/kubernetes/node

      # # TODO: My host totally messed up so I'm disabling microvm for now.
      # # inputs.microvm.nixosModules.microvm
      # # ../features/virtual-machine/microvm/host

      # #../features/virtual-machine/ssh
      # #../features/virtual-machine/virtualbox
      # ../features/window-manager/alacritty
      # # TODO: There was an erro building dwm so I'm disabling it for now.
      # #../features/window-manager/dwm
      # #../features/window-manager/ghostty
      # ../features/window-manager/gnome
      # #../features/window-manager/river
      # #../features/window-manager/slock
      # inputs.stylix.nixosModules.stylix
      # ../features/window-manager/stylix
      # #../features/window-manager/xfce
      # #../features/window-manager/xmonad
      # ../features/window-manager/xsel
      # ../features/window-manager/xclip

      #({pkgs, ...}: {
      #  # environment = {
      #  #   systemPackages = with pkgs; [
      #  #     linuxKernel.packages.linux_libre.rtl8852au
      #  #   ];
      #  # };
      #  boot = {
      #    initrd = {
      #      availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod"];
      #      kernelModules = [];
      #      luks = {
      #        devices = {
      #          "luks-2e6aa037-7c61-401f-a2e6-2dc001b01959" = {
      #            device = "/dev/disk/by-uuid/2e6aa037-7c61-401f-a2e6-2dc001b01959";
      #          };
      #        };
      #      };
      #    };
      #    # kernelPackages = with pkgs; [
      #    #   linuxKernel.packages.linux_libre.rtl8852au
      #    # ];
      #    kernelModules = [
      #      "kvm-amd"
      #      # "rtl8852au"
      #    ];
      #  };
      #  fileSystems = {
      #    "/" = {
      #      device = "/dev/disk/by-uuid/2743ae56-b79c-43c6-8f3e-e83242f1136f";
      #      fsType = "ext4";
      #    };
      #    "/boot" = {
      #      device = "/dev/disk/by-uuid/5191-DCD7";
      #      fsType = "vfat";
      #      options = ["fmask=0077" "dmask=0077"];
      #    };
      #  };
      #  # swapDevices = [
      #  #   {
      #  #     device = "/dev/disk/by-uuid/1d7ad2c2-f3e6-4e20-afef-8f73d3b030dd";
      #  #   }
      #  # ];
      #})
    ];
  };
}
