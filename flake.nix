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
    users = ["tom"];
  in
    {
      nixosConfigurations = {
        drakkar = inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs system hostname;
          };
          modules =
            [
              ./hosts/${hostname}
              {
                networking.hostName = hostname;
                # TODO: find out what this does.
                nix.registry =
                  # What does the quote do?
                  inputs.nixpkgs.lib.mapAttrs'
                  (n: v: inputs.nixpkgs.lib.nameValuePair n {flake = v;})
                  inputs;
              }
            ]
            ++ inputs.nixpkgs.lib.forEach users (u: ./users/${u}/system);
        };
      };

      homeConfigurations = {
        "tom@drakkar" = inputs.home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = {
            inherit system hostname inputs;
          };
          pkgs = pkgs;
          modules = [
            #/users/${username}/home
            ./users/tom/home
            {
              programs = {
                home-manager.enable = true;
                git.enable = true;
              };
              home = {
                #inherit username stateVersion;
                #homeDirectory = "/home/${username}";
                username = "tom";
                stateVersion = "20.09";
                homeDirectory = "/home/tom";
              };
            }
          ];
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
