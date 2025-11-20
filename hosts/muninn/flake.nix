{
  inputs = {
    # Nix Packages.
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };

    # Hardware Support.
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };

    # Comin: Git Pull Based Deployment System.
    comin = {
      url = "github:nlewo/comin";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # NixVim
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # Cursor IDE
    cursor = {
      url = "github:omarcresp/cursor-flake/main";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # Nix VS Code Extensions.
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # Stylix.
    stylix = {
      url = "github:danth/stylix";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # Generate Kubernetes Configurations with Nix.
    kubenix = {
      url = "github:hall/kubenix";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # MicroVM
    microvm = {
      url = "github:astro/microvm.nix";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # Disko
    disko = {
      url = "github:nix-community/disko";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # dwm-status tool source
    dwm-status-src = {
      url = "path:../../rust/tools/dwm-status"; # Path relative to this flake.nix
      flake = false; # Treat as a source tree, not a flake
    };

    # cl tool source
    cl-src = {
      url = "path:../../rust/tools/cl"; # Path relative to this flake.nix
      flake = false; # Treat as a source tree, not a flake
    };
  };

  outputs = inputs @ {...}: let
    name = "muninn";
    settings = (import ../../common/settings.nix {hostname = name;}).settings;
  in {
    nixosConfigurations = {
      "${name}" = inputs.nixpkgs.lib.nixosSystem {
        inherit (settings) system;
        specialArgs = {inherit inputs settings;};
        modules = [
          # System Configuration
          inputs.disko.nixosModules.disko
          ./disko.nix
          ./filesystems.nix
          ./hardware.nix

          # AI Tools
          #../../features/ai/n8n
          #../../features/ai/ollama

          # CI/CD Tools
          inputs.comin.nixosModules.comin
          ../../features/ci/comin

          # CLI Tools
          ../../features/cli/bandwhich
          ../../features/cli/bat
          ../../features/cli/bluetuith
          ../../features/cli/broot
          ../../features/cli/btop
          ../../features/cli/c
          ../../features/cli/calcurse
          ../../features/cli/cheatsheet
          ../../features/cli/cl
          ../../features/cli/create-ssh-key
          ../../features/cli/direnv
          ../../features/cli/du
          ../../features/cli/dust
          ../../features/cli/dysk
          ../../features/cli/eza
          ../../features/cli/fastfetch
          ../../features/cli/fd
          ../../features/cli/fish
          ../../features/cli/fzf
          ../../features/cli/g
          ../../features/cli/gpg
          ../../features/cli/gping
          ../../features/cli/gix
          ../../features/cli/jq
          ../../features/cli/killall
          ../../features/cli/l
          ../../features/cli/lazygit
          ../../features/cli/ll
          ../../features/cli/lnav
          ../../features/cli/nix-tree
          ../../features/cli/p
          ../../features/cli/p7zip
          ../../features/cli/procs
          ../../features/cli/ranger
          ../../features/cli/ripgrep
          ../../features/cli/spotify-player
          ../../features/cli/starship
          ../../features/cli/unrar
          ../../features/cli/unzip
          ../../features/cli/zellij

          # Creative and Design Tools
          ../../features/creative/gimp
          ../../features/creative/inkscape
          ../../features/creative/blender
          ../../features/creative/kdenlive

          # Communication
          ../../features/communication/discord
          ../../features/communication/fractal
          ../../features/communication/signal-desktop
          ../../features/communication/teams
          ../../features/communication/telegram
          ../../features/communication/weechat

          # Crypto
          ../../features/crypto/bisq
          ../../features/crypto/monero

          # Games
          ../../features/games/lutris
          ../../features/games/path-of-building
          ../../features/games/wowup

          # Learning and Documentation
          ../../features/learning/zotero
          ../../features/learning/anki

          ../../features/media/calibre
          # ../../features/media/invidious
          # ../../features/media/jellyfin
          # ../../features/media/lidarr
          # ../../features/media/prowlarr
          ../../features/media/qbittorrent
          # ../../features/media/radarr
          # ../../features/media/readarr
          # ../../features/media/sonarr
          ../../features/media/spotify
          ../../features/media/vlc
          # ../../features/media/whisparr

          # Mobile and IoT Development
          ../../features/mobile/android-studio

          # Monitoring
          #../../features/monitoring/grafana
          #../../features/monitoring/homepage-dashboard
          # ../../features/monitoring/prometheus
          # ../../features/monitoring/uptime-kuma

          # Net
          ../../features/network/chromium
          #../../features/network/searx
          #../../features/network/ssh
          ../../features/network/firefox
          # ../../features/network/qute
          # ../../features/network/ladybird
          ../../features/network/syncthing

          # NixOS
          ../../features/nixos
          ../../features/nixos/bluetooth
          ../../features/nixos/boot
          ../../features/nixos/docker
          ../../features/nixos/fonts
          ../../features/nixos/graphics
          ../../features/nixos/graphics/amd.nix
          ../../features/nixos/networking
          ../../features/nixos/networking/dns.nix
          ../../features/nixos/networking/firewall.nix
          ../../features/nixos/security/no-defaults
          ../../features/nixos/security/sudo
          ../../features/nixos/boot
          ../../features/nixos/systemd
          ../../features/nixos/auto-update
          ../../features/performance/environment
          ../../features/performance/hardware
          ../../features/performance/filesystems
          ../../features/nixos/sound
          ../../features/nixos/users
          ../../features/nixos/window-manager

          # Office
          ../../features/office/obsidian

          # Programming
          ../../features/programming/bun
          ../../features/programming/cursor
          ../../features/programming/devenv
          ../../features/programming/docker-compose
          ../../features/programming/git
          ../../features/programming/gitkraken
          ../../features/programming/glogg
          ../../features/programming/insomnia
          ../../features/programming/meld
          ../../features/programming/neovim
          ../../features/programming/node
          ../../features/programming/python
          # ../../features/programming/vscode
          # ../../features/programming/terraform

          # Security
          ../../features/security/apparmor
          ../../features/security/keepassxc
          ../../features/security/kernel
          ../../features/security/pam
          ../../features/security/tailscale
          ../../features/security/veracrypt
          ../../features/security/yubikey

          # Disks
          ../../features/storage/qdirstat

          # Virtual Machine
          #../../features/virtual-machine/base
          #../../features/virtual-machine/kubernetes/k3s
          #../../features/virtual-machine/kubernetes/master
          #../../features/virtual-machine/kubernetes/node
          ##inputs.microvm.nixosModules.host
          ##../../features/virtual-machine/microvm/host
          ##../../features/virtual-machine/microvm/target/host-network.nix
          #../../features/virtual-machine/microvm/web/host-network.nix
          #../../features/virtual-machine/ssh
          #../../features/virtual-machine/virtualbox

          # Window Manager
          ../../features/window-manager/alacritty
          ../../features/window-manager/dwm
          ../../features/window-manager/dwm-status
          #../../features/window-manager/ghostty
          ../../features/window-manager/gnome
          #../../features/window-manager/slock
          inputs.stylix.nixosModules.stylix
          ../../features/window-manager/stylix
          # ../../features/window-manager/xfce
          #../../features/window-manager/xmonad
          ../../features/window-manager/xsel
          ../../features/window-manager/xclip
        ];
      };
    };
  };
}
