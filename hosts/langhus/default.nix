{
  inputs,
  specialArgs,
  ...
}: let
  settings = import ./settings.nix;
in
  inputs.nixpkgs.lib.nixosSystem {
    specialArgs =
      specialArgs
      // {
        inherit settings;
      };
    modules = [
      ./system
    ];
  }
