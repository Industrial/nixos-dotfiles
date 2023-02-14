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

    mkHome = home-manager.lib.homeManagerConfiguration;
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

    homeConfigurations."tom@drakkar" = mkHome {
      pkgs = self.outputs.nixosConfigurations.drakkar.pkgs;
      modules = [
        ./users/tom/home.nix
      ];
      extraSpecialArgs = {
        inherit self inputs;
      };
    };
  };
}

