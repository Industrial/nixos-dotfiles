{
  self,
  inputs,
  lib,
  ...
}: {
  flake = let
    specialArgs = {inherit inputs self;};
  in {
    nixosConfigurations = {
      langhus = import ./langhus {inherit inputs specialArgs;};
      smithja = import ./smithja {inherit inputs specialArgs;};
    };
  };
}
