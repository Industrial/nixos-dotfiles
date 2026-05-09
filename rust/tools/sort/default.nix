# Rust `sort` (POSIX/GNU subset), `id_effect` runtime.
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
  cargoNix.workspaceMembers.sort.build.overrideAttrs (oldAttrs: {
    meta = with lib; {
      description = "Sort lines of text (dotfiles Rust sort)";
      license = licenses.mit;
    };
  })
