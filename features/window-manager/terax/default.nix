# Terax - AI-native terminal (Tauri): https://github.com/crynta/terax-ai
{
  pkgs,
  lib,
  ...
}: {
  environment = {
    systemPackages = lib.optional (pkgs.stdenv.hostPlatform.system == "x86_64-linux") (
      pkgs.callPackage ./package.nix {
        gdk_pixbuf = pkgs."gdk-pixbuf";
      }
    );
  };
}
