# Rust `cat` (dotfiles). Installed with higher priority than coreutils where names collide.
{
  pkgs,
  lib,
  inputs,
  ...
}: let
  catPkg = lib.hiPrio (pkgs.callPackage inputs.cat-src {});
in {
  environment.systemPackages = [catPkg];
}
