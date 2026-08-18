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

    # Caelestia Shell (Quickshell) - nested tryout; see hyprland-nested-caelestia.lua
    # git.outfoxxed.me is often unreachable; use the GitHub mirror for quickshell.
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
    hostname = "drakkar";
    settings = (import ../../common/settings.nix {hostname = hostname;}).settings;
  in {
    nixosConfigurations."${hostname}" = inputs.nixpkgs.lib.nixosSystem {
      inherit (settings) system;
      specialArgs = {
        inherit inputs settings;
        nixpkgs = import inputs.nixpkgs {
          overlays = [
            (self: super: {
              python3Packages =
                super.python3Packages
                // {
                  nanoemoji = super.python3Packages.nanoemoji.overrideAttrs (old: {
                    hash = "sha256-FysyKC01XBnRiur5RR9fcsTxQqE8x0JJHSoe3q6JtKc=";
                  });
                };
            })
          ];
        };
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
}
