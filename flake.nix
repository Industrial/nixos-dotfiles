{
  description = "System Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
  };

  outputs = inputs: let
    hostname = "drakkar";
    system = "x86_64-linux";
    pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [
        (
          final: prev: {
            lutris = prev.lutris.overrideAttrs (old: {
              src = final.fetchFromGitHub {
                owner = "NixOS";
                repo = "nixpkgs";
                rev = "b6388ae3ee77d7fd38dbcba94414fd735a9292e6";
                sha256 = "1gz13nk6j0c9ax9ckr5k2ljr2w6wlpb6v7pplz20sgdlvlwh6z49";
              };
            });
          }
        )
      ];
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
