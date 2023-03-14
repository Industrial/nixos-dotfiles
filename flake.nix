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
        modules = with self.nixosModules; [
          {config = {nix.registry.nixpkgs.flake = nixpkgs;};}
          ./hosts/drakkar/configuration.nix
          home-manager.nixosModules.home-manager
          gnome
        ];
      };
    };

    # TODO: Rewrite hosts/drakkar/configuration.nix to modules.
    nixosModules = {
      gnome = import ./modules/gnome.nix {inherit pkgs;};
    };

    homeConfigurations.tom = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      modules = [./users/tom/home.nix];
    };
  };
}
