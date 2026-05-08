# Interactive Brokers Gateway (IB Gateway), latest standalone Linux x64.
# Same Install4J + bundled JRE pattern as TWS: run installer and app under
# steam-run on NixOS.
#
# Logs: default `~/.cache/ib-gateway-launch.log` (override with IBGW_LOG).
{
  pkgs,
  lib,
  ...
}: let
  inherit (pkgs) stdenv fetchurl steam-run;

  installerUrl = "https://download2.interactivebrokers.com/installers/ibgateway/latest-standalone/ibgateway-latest-standalone-linux-x64.sh";

  # nix-prefetch-url "${installerUrl}"
  installerHash = "sha256-hcU2gis0Tv/2OgniJrP+QmLn3AqIA6SVCeZw/cYfxFA=";

  launcherTemplate = ./ib-gateway-launcher.sh.in;

  ib-gateway = stdenv.mkDerivation {
    pname = "ib-gateway-latest-standalone";
    version = "latest";

    src = fetchurl {
      url = installerUrl;
      hash = installerHash;
    };

    dontUnpack = true;

    nativeBuildInputs = [steam-run];

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin" "$out/opt/ib-gateway" "$out/share/applications"
      export HOME="$PWD/.install-home"
      mkdir -p "$HOME"
      export INSTALL4J_TEMP="$PWD/.install4j-temp"
      mkdir -p "$INSTALL4J_TEMP"

      installer="$PWD/ibgateway-latest-standalone-linux-x64.sh"
      cp "$src" "$installer"
      chmod +x "$installer"
      ${steam-run}/bin/steam-run "$installer" -q -dir "$out/opt/ib-gateway"

      sed \
        -e "s#@shell@#${stdenv.shell}#g" \
        -e "s#@steamrun@#${steam-run}/bin/steam-run#g" \
        -e "s#@gwroot@#$out/opt/ib-gateway#g" \
        "${launcherTemplate}" > "$out/bin/ibgateway"
      chmod +x "$out/bin/ibgateway"

      icon="$out/opt/ib-gateway/.install4j/ibgateway.png"
      if [ ! -f "$icon" ]; then
        icon="$out/opt/ib-gateway/ibgateway.png"
      fi

      {
        printf '%s\n' '[Desktop Entry]'
        printf '%s\n' 'Version=1.0'
        printf '%s\n' 'Type=Application'
        printf '%s\n' 'Name=IB Gateway'
        printf '%s\n' 'Comment=Interactive Brokers Gateway'
        printf '%s\n' "Exec=$out/bin/ibgateway %u"
        printf '%s\n' "TryExec=$out/bin/ibgateway"
        printf '%s\n' "Icon=$icon"
        printf '%s\n' 'Terminal=false'
        printf '%s\n' 'Categories=Office;Finance;Network;'
        printf '%s\n' 'StartupNotify=true'
      } > "$out/share/applications/ib-gateway.desktop"

      runHook postInstall
    '';

    meta = with lib; {
      description = "Interactive Brokers Gateway (latest standalone)";
      homepage = "https://www.interactivebrokers.com/en/trading/ibgateway-stable.php";
      license = licenses.unfree;
      sourceProvenance = with sourceTypes; [binaryNativeCode];
      platforms = ["x86_64-linux"];
      mainProgram = "ibgateway";
      maintainers = [];
    };
  };
in {
  environment.systemPackages = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
    ib-gateway
  ];
}
