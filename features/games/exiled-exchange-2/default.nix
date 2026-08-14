# Exiled Exchange 2 — trading companion for Path of Exile 2.
# https://exiled-exchange2.com/
# Official Linux release: GitHub AppImage (see site download table).
{
  pkgs,
  lib,
  ...
}: let
  version = "0.12.2";
  appimage = pkgs.fetchurl {
    url = "https://github.com/Kvan7/Exiled-Exchange-2/releases/download/v${version}/exiled-exchange-2-${version}.AppImage";
    hash = "sha256-8SK/Fqf3t9G9hPNLnaNxgBNgMVv4Rke96xi9ufvbEHs=";
  };
  exiled-exchange-2 = pkgs.appimageTools.wrapType2 {
    pname = "exiled-exchange-2";
    inherit version;
    src = appimage;
    extraPkgs = _pkgs: [];
    meta = {
      description = "Trading companion for Path of Exile 2";
      homepage = "https://exiled-exchange2.com/";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux"];
    };
  };
in {
  environment.systemPackages = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
    exiled-exchange-2
  ];
}
