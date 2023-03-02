{
  description = "System Flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  }: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config = {allowUnfree = true;};
    };
  in {
    nixosConfigurations = {
      drakkar = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [./hosts/drakkar/configuration.nix];
      };
    };

    homeConfigurations.tom = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      modules = [./users/tom/home.nix];
    };
  };
}
