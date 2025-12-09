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

    # cl tool source
    cl-src = {
      url = "path:../../rust/tools/cl"; # Path relative to this flake.nix
      flake = false; # Treat as a source tree, not a flake
    };
  };

  outputs = inputs @ {...}: let
    hostname = "drakkar";
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
          inputs.disko.nixosModules.disko
          ./disko.nix
          ./filesystems.nix
          ./hardware.nix

          # Profiles
          ../../profiles/base.nix
          ../../profiles/development.nix
          ../../profiles/desktop.nix
          ../../profiles/gaming.nix
          ../../profiles/creative.nix
          ../../profiles/communication.nix
          ../../profiles/crypto.nix
          ../../profiles/learning.nix

          # Host-specific additions
          ../../features/nixos/graphics/amd.nix
          ../../features/hardware/zsa-voyager

          # AI Tools (commented for future use)
          # ../../features/ai/n8n
          # ../../features/ai/ollama
          # ../../features/ai/opencode

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

          # Virtual Machine (commented for future use)
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

          # Window Manager (commented for future use)
          #../../features/window-manager/ghostty
          #../../features/window-manager/slock
          # ../../features/window-manager/xfce
        ];
      };
    };
  };
}
