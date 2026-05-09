# Rust `head` (dotfiles).
{
  pkgs,
  lib,
  inputs,
  ...
}: let
  headPkg = lib.hiPrio (pkgs.callPackage inputs.head-src {});
in {
  environment.systemPackages = [headPkg];
}
