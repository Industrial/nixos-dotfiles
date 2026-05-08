# Rust `rev` (dotfiles). Installed with higher priority than coreutils where names collide.
{
  pkgs,
  lib,
  inputs,
  ...
}: let
  revPkg = lib.hiPrio (pkgs.callPackage inputs.rev-src {});
in {
  environment.systemPackages = [revPkg];
}
