# OpenIDEA — IntelliJ IDEA–style IDE rebuilt in Rust (Tauri).
# https://github.com/l0ng-ai/openidea
# Not in nixpkgs; upstream ships no flake. Official Linux release: GitHub AppImage.
{
  pkgs,
  lib,
  ...
}: let
  pname = "openidea";
  version = "0.1.18";
  src = pkgs.fetchurl {
    url = "https://github.com/l0ng-ai/openidea/releases/download/v${version}/OpenIDEA_${version}_amd64.AppImage";
    hash = "sha256-M1XD759ZQdNQIqYhhn1J81TO6Z1ZD+DCL1gjidsy8Bs=";
  };
  appimageContents = pkgs.appimageTools.extractType2 {inherit pname version src;};
  openidea = pkgs.appimageTools.wrapType2 {
    inherit pname version src;
    extraPkgs = _pkgs: [];
    extraInstallCommands = ''
      if [ -d ${appimageContents}/usr/share/icons ]; then
        mkdir -p $out/share
        cp -r ${appimageContents}/usr/share/icons $out/share/
      fi
      for desktop in ${appimageContents}/*.desktop; do
        install -Dm644 "$desktop" $out/share/applications/openidea.desktop
        sed -i -E 's|^Exec=[^ ]+|Exec=openidea|' $out/share/applications/openidea.desktop
        break
      done
    '';
    meta = {
      description = "IntelliJ IDEA–style IDE rebuilt in Rust";
      homepage = "https://github.com/l0ng-ai/openidea";
      license = lib.licenses.asl20;
      platforms = ["x86_64-linux"];
      mainProgram = "openidea";
    };
  };
in {
  environment.systemPackages = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
    openidea
  ];
}
