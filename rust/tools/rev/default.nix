# Rust `rev` (POSIX-oriented), `id_effect` runtime.
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
  cargoNix.workspaceMembers.rev.build.overrideAttrs (oldAttrs: {
    meta = with lib; {
      description = "Reverse lines per byte (dotfiles Rust rev)";
      license = licenses.mit;
    };
  })
