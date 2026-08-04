# nixstore — Nix store path-info / GC CLI
#
# Dev-first: cargo-built wrapper (see ./package.nix).
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
