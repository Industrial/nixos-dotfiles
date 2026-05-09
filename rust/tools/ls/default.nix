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
  cargoNix.workspaceMembers.ls.build.overrideAttrs (_oldAttrs: {
    meta = with lib; {
      description = "List directory contents (GNU parity goal; dotfiles Rust ls)";
      license = licenses.mit;
    };
  })
