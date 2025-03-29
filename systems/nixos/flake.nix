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
  };
  outputs = inputs @ {...}: {
    nixosConfigurations =
      {}
      // (import ../../hosts/drakkar.nix {inherit inputs;})
      // (import ../../hosts/gandi_nixos_001.nix {inherit inputs;})
      // (import ../../hosts/huginn.nix {inherit inputs;})
      // (import ../../hosts/langhus.nix {inherit inputs;})
      // (import ../../hosts/mimir.nix {inherit inputs;})
      // (import ../../hosts/vm_test.nix {inherit inputs;})
      // (import ../../hosts/vm_web.nix {inherit inputs;})
      // (import ../../hosts/vm_database.nix {inherit inputs;})
      // (import ../../hosts/vm_management.nix {inherit inputs;});
  };
}
