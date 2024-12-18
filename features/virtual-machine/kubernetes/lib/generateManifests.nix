{
  inputs,
  settings,
  pkgs,
}: services: let
  generateManifest = import ./generateManifest.nix {
    inherit inputs settings pkgs;
  };
in
  builtins.listToAttrs (map
    (name: {
      inherit name;
      value = generateManifest name;
    })
    services)
