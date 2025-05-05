{
  inputs = {
    # Nix Packages.
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
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

  outputs = inputs @ {self, ...}: {
    nixosConfigurations = let
      hostname = "vm_test";
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
        ];
      };
    };
  };
}
