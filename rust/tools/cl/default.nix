# Make the cl tool available in the system.
{
  lib,
  pkgs,
  ...
}: let
  cargoNix = import ./Cargo.nix {
    inherit pkgs;
    defaultCrateOverrides = pkgs.defaultCrateOverrides;
  };
in
  cargoNix.workspaceMembers.cl.build.overrideAttrs (oldAttrs: {
    meta = with lib; {
      description = "A simple terminal clear command written in Rust";
      homepage = "";
      license = licenses.mit;
      maintainers = [];
    };
  })
