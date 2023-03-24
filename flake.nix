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
    local-overlays = import ./overlays;
    overlays = [
      local-overlays
    ];
    lib = import ./lib {inherit inputs overlays;};
  in
    {
      nixosConfigurations = {
        drakkar = lib.mkSystem {
          hostname = "drakkar";
          system = "x86_64-linux";
          users = ["tom"];
        };
      };

      homeConfigurations = {
        "tom@drakkar" = lib.mkHome {
          hostname = "drakkar";
          system = "x86_64-linux";
          username = "tom";
          stateVersion = "20.09";
        };
      };
    }
    // inputs.flake-utils.lib.eachDefaultSystem
    (
      system: let
        pkgs = import inputs.nixpkgs {
          inherit system overlays;
        };
      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [home-manager git];
          NIX_CONFIG = "experimental-features = nix-command flakes";
        };
      }
    );
}
