# nix1-hash — 1:1 Rust reimplementation of stock `nix-hash` (dev-first PATH).
#
# Ships the parallel binary `nix1-hash` (does NOT shadow `nix-hash`).
# Soak: `alias nix-hash=nix1-hash` or enable promote leaf after oracle green.
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
