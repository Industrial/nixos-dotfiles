# pi — Pi coding agent CLI
# https://pi.dev
#
# Provides `pi` on PATH as a NixOS system package.
{pkgs, ...}: {
  environment = {
    variables = {
      LEAN_CTX_PI_MODE = "replace";
    };

    systemPackages = [
      (pkgs.callPackage ./package.nix {
        nodejs = pkgs.nodejs_22;
      })
      (pkgs.callPackage ./plugins/pi-mcp-beads/default.nix {})
    ];
  };
}
