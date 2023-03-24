{
  description = "System Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs: let
    hostname = "drakkar";
    system = "x86_64-linux";
    local-overlays = import ./overlays;
    overlays = [
      local-overlays
    ];
    pkgs = import inputs.nixpkgs {
      inherit overlays;
      system = system;
      config.allowUnfree = true;
      config.allowBroken = false;
    };
    lib = import ./lib {
      inherit inputs overlays pkgs;
    };
  in
    {
      nixosConfigurations = {
        drakkar = lib.mkSystem {
          hostname = hostname;
          system = system;
          users = ["tom"];
        };
      };

      homeConfigurations = {
        "tom@drakkar" = lib.mkHome {
          hostname = hostname;
          system = system;
          username = "tom";
          stateVersion = "20.09";
        };
      };
    }
    // inputs.flake-utils.lib.eachDefaultSystem
    (
      system: {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [home-manager git];
          NIX_CONFIG = "experimental-features = nix-command flakes";
        };
      }
    );
}
