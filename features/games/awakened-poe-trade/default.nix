# Awakened PoE Trade — price-check overlay for Path of Exile 1.
# https://github.com/SnosMe/awakened-poe-trade
{
  pkgs,
  lib,
  ...
}: let
  version = "3.29.104";
  appimage = pkgs.fetchurl {
    url = "https://github.com/SnosMe/awakened-poe-trade/releases/download/v${version}/Awakened-PoE-Trade-${version}.AppImage";
    hash = "sha256-ApZwjy1tJwUtevLA7QY8/zrnHI5Tt4aXMpTo+5VWGUg=";
  };
  awakened-poe-trade = pkgs.appimageTools.wrapType2 {
    pname = "awakened-poe-trade";
    inherit version;
    src = appimage;
    extraPkgs = _pkgs: [];
    meta = {
      description = "Price-check overlay for Path of Exile 1";
      homepage = "https://github.com/SnosMe/awakened-poe-trade";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux"];
    };
  };
in {
  environment.systemPackages = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
    awakened-poe-trade
  ];
}
