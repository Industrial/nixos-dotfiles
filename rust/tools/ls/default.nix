# Rust `ls` (POSIX-oriented subset), `id_effect` runtime.
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
  cargoNix.workspaceMembers.ls.build.overrideAttrs (oldAttrs: {
    meta = with lib; {
      description = "List directory contents (dotfiles Rust ls)";
      license = licenses.mit;
    };
  })
