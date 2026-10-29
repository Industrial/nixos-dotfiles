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
    # Libraries the bundled .so files need but the AppImage does not ship.
    extraPkgs = p:
      with p; [
        e2fsprogs # libcom_err
        expat
        fontconfig
        freetype
        fribidi
        gmp
        harfbuzz
        libdrm
        libgbm
        libGL
        libgpg-error
        wayland
        libx11
        libxcb
        zlib
      ];
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
    # The Agents panel spawns its ACP adapters through `npx` with a hardcoded
    # version pin (e.g. `npx -y @agentclientprotocol/claude-agent-acp@0.97.0`)
    # and reports "was not found on PATH" otherwise. OpenIDEA derives its env
    # from `$SHELL -ilc` at startup, so the adapter has to be reachable from the
    # login shell — a per-project devenv shell is not enough. Full `nodejs`, not
    # `nodejs-slim`: the slim build ships no npm/npx.
    pkgs.nodejs
  ];
}
