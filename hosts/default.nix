{
  self,
  inputs,
  ...
}: {
  flake = let
    specialArgs = {inherit inputs self;};
  in {
    nixosConfigurations = {
      langhus = import ./langhus {inherit inputs specialArgs;};
    };
  };
}
