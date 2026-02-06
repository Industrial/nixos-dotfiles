# Make the oomkiller tool available in the system.
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
  cargoNix.workspaceMembers.oomkiller.build.overrideAttrs (oldAttrs: {
    meta = with lib; {
      description = "A daemon that monitors system memory and kills the highest memory-consuming process when memory usage exceeds 90%";
      homepage = "";
      license = licenses.mit;
      maintainers = [];
    };
  })
