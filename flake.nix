{
  description = "System Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
  };

  outputs = inputs: let
    hostname = "drakkar";
    system = "x86_64-linux";
    overlays = import ./overlays/default.nix;
    pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [overlays];
      config = {
        allowUnfree = true;
        allowBroken = false;
      };
    };
  in {
    nixosConfigurations = {
      drakkar = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/${hostname}
          ./users/tom/system
        ];
      };
    };

    homeConfigurations = {
      "tom@drakkar" = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = pkgs;
        modules = [
          ./users/tom/home
        ];
      };
    };
  };
}
