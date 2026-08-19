{
  inputs = {
    # Nix Packages.
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };

    # Hyprland 0.55+ (Lua configs); nixpkgs-unstable may lag behind.
    # Do not pin hyprland.inputs.nixpkgs here: Hyprland may require a newer nixpkgs
    # (e.g. lua5_5) than this flake's nixpkgs provides.
    hyprland = {
      url = "github:hyprwm/hyprland";
    };

    # Caelestia Shell (Quickshell) — same as drakkar; git.outfoxxed.me mirrored.
    quickshell = {
      url = "github:quickshell-mirror/quickshell/28771c7c74b42e20afca0b1b63980cb46515537c";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.quickshell.follows = "quickshell";
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

    # Disko
    disko = {
      url = "github:nix-community/disko";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # oomkiller tool source
    oomkiller-src = {
      url = "path:../../rust/tools/oomkiller"; # Path relative to this flake.nix
      flake = false; # Treat as a source tree, not a flake
    };

    # nixos-update-notifier tool source
    nixos-update-notifier-src = {
      url = "path:../../rust/tools/nixos-update-notifier";
      flake = false;
    };

    # Assay workspace (assay, nixq, nixdrv, nixstore, nixfetch)
    assay = {
      url = "github:Industrial/assay";
    };
  };

  outputs = inputs @ {...}: let
    hostname = "huginn";
    settings = (import ../../common/settings.nix {hostname = hostname;}).settings;
  in {
    nixosConfigurations = {
      "${hostname}" = inputs.nixpkgs.lib.nixosSystem {
        inherit (settings) system;
        specialArgs = {
          inherit inputs settings;
        };
        modules = [
          # System Configuration (host-specific)
          # Note: Disko is commented out for this host
          # inputs.disko.nixosModules.disko
          # ./disko.nix
          ./filesystems.nix
          ./hardware.nix

          # Profiles
          ../../profiles/base.nix
          ../../profiles/development.nix
          ../../profiles/desktop.nix
          #../../profiles/gaming.nix
          ../../profiles/communication.nix
          # ../../profiles/crypto.nix
          ../../profiles/learning.nix

          # # Host-specific additions
          # ../../features/nixos/graphics/amd.nix
          # ../../features/hardware/zsa-voyager

          # AI Tools (commented for future use)
          # ../../features/ai/n8n
          # ../../features/ai/ollama
          # ../../features/ai/opencode

          # Creative and Design Tools (commented - not used on this host)
          # ../../features/creative/gimp
          # ../../features/creative/inkscape
          # ../../features/creative/blender
          # ../../features/creative/kdenlive

          # Media (commented for future use)
          # ../../features/media/invidious
          # ../../features/media/jellyfin
          # ../../features/media/lidarr
          # ../../features/media/prowlarr
          # ../../features/media/radarr
          # ../../features/media/readarr
          # ../../features/media/sonarr
          # ../../features/media/whisparr

          # Mobile and IoT Development (commented for future use)
          # ../../features/mobile/android-studio

          # Monitoring (commented for future use)
          #../../features/monitoring/grafana
          #../../features/monitoring/homepage-dashboard
          # ../../features/monitoring/prometheus
          # ../../features/monitoring/uptime-kuma

          # Network (commented for future use)
          #../../features/network/searx
          #../../features/network/ssh
          # ../../features/network/qute
          # ../../features/network/ladybird
          # ../../features/network/syncthing

          # Office (commented for future use)
          # ../../features/office/obsidian

          # Programming (commented for future use)
          # ../../features/programming/vscode
          # ../../features/programming/terraform

          # Security (commented for future use)
          # ../../features/security/kernel
          # ../../features/security/tailscale

          # Window Manager
          ../../features/window-manager/hyprland
          #../../features/window-manager/ghostty
          #../../features/window-manager/slock
          # ../../features/window-manager/xfce
        ];
      };
    };
  };
}
