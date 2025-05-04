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

    # NixOS Anywhere
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs = {
        nixpkgs.follows = "nixpkgs";
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
  };

  outputs = inputs @ {self, ...}: {
    nixosConfigurations = let
      hostname = "vm_target";
      settings = (import ../../common/settings.nix {hostname = hostname;}).settings;
    in {
      "${hostname}" = inputs.nixpkgs.lib.nixosSystem {
        inherit (settings) system;
        specialArgs = {
          inherit inputs settings;
        };
        modules = [
          inputs.microvm.nixosModules.microvm
          ../features/virtual-machine/microvm/base
          ../features/virtual-machine/microvm/ssh
          ../features/virtual-machine/microvm/target
        ];
      };
    };
  };
}
