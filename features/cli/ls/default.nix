# Rust `ls` (dotfiles).
{
  pkgs,
  lib,
  inputs,
  ...
}: let
  lsPkg = lib.hiPrio (pkgs.callPackage inputs.ls-src {});
in {
  environment.systemPackages = [lsPkg];
}
