# Make the assay tool available in the system.
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
  cargoNix.workspaceMembers.assay.build.overrideAttrs (oldAttrs: {
    meta = with lib; {
      description = "Assay — Nix unit testing: claim algebra + isolated eval runner";
      homepage = "";
      license = licenses.mit;
      maintainers = [];
    };
  })
