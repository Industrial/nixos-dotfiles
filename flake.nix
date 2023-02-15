{
  description = "System Flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-22.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };

  outputs = {
    self
    , nixpkgs
    , home-manager
    , ...
  } @ inputs: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };

    lib = nixpkgs.lib;
  in {
    nixosConfigurations = {
      drakkar = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/drakkar/configuration.nix
        ];
        #specialArgs = {
        #  inherit inputs;
        #};
      };
    };

    homeConfigurations.tom = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      modules = [
        ./users/tom/home.nix
      ];
    };
  };
}

