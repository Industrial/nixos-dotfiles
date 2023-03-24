{
  pkgs,
  inputs,
  overlays,
}: {
  mkSystem = {
    hostname,
    system,
    users ? [],
  }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs system hostname;
      };
      modules =
        [
          ../hosts/${hostname}
          {
            networking.hostName = hostname;
            nix.registry =
              inputs.nixpkgs.lib.mapAttrs'
              (n: v: inputs.nixpkgs.lib.nameValuePair n {flake = v;})
              inputs;
          }
        ]
        ++ inputs.nixpkgs.lib.forEach users (u: ../users/${u}/system);
    };

  mkHome = {
    username,
    system,
    hostname,
    stateVersion,
  }:
    inputs.home-manager.lib.homeManagerConfiguration {
      extraSpecialArgs = {
        inherit system hostname inputs;
      };
      pkgs = pkgs;
      modules = [
        ../users/${username}/home
        {
          programs = {
            home-manager.enable = true;
            git.enable = true;
          };
          home = {
            inherit username stateVersion;
            homeDirectory = "/home/${username}";
          };
        }
      ];
    };
}
