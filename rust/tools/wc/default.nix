# Make the wc tool available in the system (Rust implementation, GNU-compatible).
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
  cargoNix.workspaceMembers.wc.build.overrideAttrs (oldAttrs: {
    meta = with lib; {
      description = "Print newline, word, byte, and character counts (GNU wc compatible)";
      homepage = "";
      license = licenses.mit;
      maintainers = [];
    };
  })
