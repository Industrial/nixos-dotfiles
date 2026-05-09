# Tolaria — Desktop app to manage markdown knowledge bases
# https://tolaria.md
{
  pkgs,
  lib,
  ...
}: let
  version = "2026.4.30";
  appimage = pkgs.fetchurl {
    url = "https://github.com/refactoringhq/tolaria/releases/download/stable-v${version}/Tolaria_${version}_amd64.AppImage";
    hash = "sha256-YHJjoP4rQphAQ0Cb0M1kni6Cx0hJNR0aY68fwJbVpGc=";
  };
  tolaria = pkgs.appimageTools.wrapType2 {
    pname = "tolaria";
    version = version;
    src = appimage;
    extraPkgs = _pkgs: [];
  };
in {
  environment.systemPackages = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
    tolaria
  ];
}
