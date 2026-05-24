# pi — Pi coding agent CLI
# https://pi.dev
#
# Provides `pi` on PATH as a NixOS system package.
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {
      nodejs = pkgs.nodejs_22;
    })
  ];
}
