# Build a nixosConfiguration for a fleet host.
{inputs}: hostname: let
  settings = (import ../common/settings.nix {inherit hostname;}).settings;
in
  inputs.nixpkgs.lib.nixosSystem {
    inherit (settings) system;
    specialArgs = {inherit inputs settings;};
    modules = [../hosts/${hostname}/configuration.nix];
  }
