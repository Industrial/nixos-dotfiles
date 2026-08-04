# nix-hash — 1:1 Rust reimplementation of stock `nix-hash` (dev-first PATH).
#
# Installs as `nix-hash`, replacing the classic Nix hash CLI on PATH when
# this feature is enabled.
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
