# OpenPencil — open-source design editor (Figma-compatible, .fig files, AI tools).
# https://openpencil.dev/
{
  pkgs,
  lib,
  ...
}: let
  version = "0.10.0";
  appimage = pkgs.fetchurl {
    url = "https://github.com/open-pencil/open-pencil/releases/download/v${version}/OpenPencil_${version}_amd64.AppImage";
    hash = "sha256-9SdHH1c4z9fQ2EBc7jgr5mY4iR8FZOb3h3FKP6xTW6I=";
  };
  openpencil = pkgs.appimageTools.wrapType2 {
    pname = "openpencil";
    version = version;
    src = appimage;
    extraPkgs = _pkgs: [];
  };
in {
  environment.systemPackages = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
    openpencil
  ];
}
