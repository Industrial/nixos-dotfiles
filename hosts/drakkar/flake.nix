{
  inputs = {
    # Nix Packages.
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };

    # Hyprland 0.55+ (Lua configs); nixpkgs-unstable may lag behind.
    hyprland = {
      url = "github:hyprwm/hyprland";
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

    # Assay workspace (assay, nixq, nixdrv, nixstore, nixfetch)
    assay = {
      url = "github:Industrial/assay";
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
          ../../profiles/ai.nix
          ../../profiles/base.nix
          ../../profiles/development.nix
          ../../profiles/desktop.nix
          ../../profiles/gaming.nix
          # ../../profiles/creative.nix
          ../../profiles/communication.nix
          # ../../profiles/crypto.nix
          # ../../profiles/learning.nix

          # Host-specific additions
          ../../features/nixos/graphics/amd.nix
          ../../features/hardware/zsa-voyager
        ];
      };
    };
  };
}
