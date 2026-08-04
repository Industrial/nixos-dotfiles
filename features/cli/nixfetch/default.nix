# nixfetch — fixed-output fetch + hash verify CLI
#
# Dev-first: cargo-built wrapper (see ./package.nix).
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
