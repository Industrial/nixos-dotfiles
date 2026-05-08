# Rust `sort` (dotfiles).
{
  pkgs,
  lib,
  inputs,
  ...
}: let
  sortPkg = lib.hiPrio (pkgs.callPackage inputs.sort-src {});
in {
  environment.systemPackages = [sortPkg];
}
