# Rust `cat` (POSIX/GNU subset), `id_effect` runtime.
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
  cargoNix.workspaceMembers.cat.build.overrideAttrs (oldAttrs: {
    meta = with lib; {
      description = "Concatenate files (dotfiles Rust cat)";
      license = licenses.mit;
    };
  })
