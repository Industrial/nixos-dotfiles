# Rust `head` (POSIX-oriented subset), `id_effect` runtime.
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
  cargoNix.workspaceMembers.head.build.overrideAttrs (oldAttrs: {
    meta = with lib; {
      description = "Output first lines or bytes of files (dotfiles Rust head)";
      license = licenses.mit;
    };
  })
