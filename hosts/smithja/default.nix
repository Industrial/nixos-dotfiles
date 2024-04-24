{
  inputs,
  specialArgs,
  ...
}: let
  settings = import ./settings.nix;
in
  inputs.nix-darwin.lib.darwinSystem {
    specialArgs =
      specialArgs
      // {
        inherit settings;
      };
    modules = [
      ./system
    ];
  }
