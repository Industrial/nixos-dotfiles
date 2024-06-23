# {
#   description = "Flake for Ansifilter";
#   inputs = {
#     nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
#   };
#   outputs = { nixpkgs, ... }: let
#     inherit (builtins) currentSystem;
#     pkgs = nixpkgs.legacyPackages.${currentSystem};
#     package = pkgs.ansifilter;
#   in {
#     packages.${builtins.currentSystem}.default = package;
#     devShell.${builtins.currentSystem} = pkgs.mkShell {
#       buildInputs = [
#         package
#       ];
#     };
#   };
# }

{
  description = "Flake for Ansifilter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { nixpkgs, ... }: {
    packages = systems: map (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      package = pkgs.ansifilter;
    in { inherit package; })
      systems;

    devShell = systems: map (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in { default = pkgs.mkShell {
      buildInputs = [
        pkgs.ansifilter
      ];
    }; })
      systems;
  };
}