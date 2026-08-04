# nixq — NixOS query / structural equality CLI
#
# Dev-first: cargo-built wrapper (see ./package.nix).
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
