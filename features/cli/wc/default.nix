# Rust `wc` (GNU-compatible). Installed with higher priority than coreutils so `wc` resolves here.
{
  pkgs,
  lib,
  inputs,
  ...
}: let
  wcPkg = lib.hiPrio (pkgs.callPackage inputs.wc-src {});
in {
  environment.systemPackages = [wcPkg];
}
