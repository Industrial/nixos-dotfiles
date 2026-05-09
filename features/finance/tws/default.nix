# Interactive Brokers Trader Workstation (TWS), stable standalone Linux x64.
# Upstream ships an Install4J self-extractor; the bundled JRE expects a FHS
# environment, so the installer and launcher run under steam-run (same as a
# manual install on NixOS).
#
# We install a real .desktop entry (Exec= absolute path to our wrapper). If GNOME
# runs the upstream `tws` script directly, the bundled JVM will not start on
# NixOS (no FHS). Remove stale `~/.local/share/applications/*tws*.desktop` files
# from an old manual install so they do not shadow this one.
#
# Logs: default `~/.cache/ib-tws-launch.log` (override with TWS_LOG). From a
# terminal, stdout/stderr are also mirrored when stdout is a TTY.
{
  pkgs,
  lib,
  ...
}: let
  inherit (pkgs) stdenv fetchurl steam-run;

  installerUrl = "https://download2.interactivebrokers.com/installers/tws/stable-standalone/tws-stable-standalone-linux-x64.sh";

  # nix-prefetch-url "${installerUrl}"
  installerHash = "sha256-rGsJDvhcw2klGYOCwVFiPmGWh2CKGQa1wTZh2JGIyWc=";

  launcherTemplate = ./tws-launcher.sh.in;

  ib-tws = stdenv.mkDerivation {
    pname = "ib-tws-stable-standalone";
    version = "stable";

    src = fetchurl {
      url = installerUrl;
      hash = installerHash;
    };

    dontUnpack = true;

    nativeBuildInputs = [steam-run];

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin" "$out/opt/ib-tws" "$out/share/applications"
      export HOME="$PWD/.install-home"
      mkdir -p "$HOME"
      export INSTALL4J_TEMP="$PWD/.install4j-temp"
      mkdir -p "$INSTALL4J_TEMP"

      # $src lives in the read-only store; chmod +x there fails. Copy first.
      installer="$PWD/tws-stable-standalone-linux-x64.sh"
      cp "$src" "$installer"
      chmod +x "$installer"
      # Run the script itself (not `bash $src`) so Install4j can open $0 for the embedded payload.
      ${steam-run}/bin/steam-run "$installer" -q -dir "$out/opt/ib-tws"

      sed \
        -e "s#@shell@#${stdenv.shell}#g" \
        -e "s#@steamrun@#${steam-run}/bin/steam-run#g" \
        -e "s#@twroot@#$out/opt/ib-tws#g" \
        "${launcherTemplate}" > "$out/bin/tws"
      chmod +x "$out/bin/tws"

      icon="$out/opt/ib-tws/.install4j/tws.png"
      if [ ! -f "$icon" ]; then
        icon="$out/opt/ib-tws/tws.png"
      fi

      {
        printf '%s\n' '[Desktop Entry]'
        printf '%s\n' 'Version=1.0'
        printf '%s\n' 'Type=Application'
        printf '%s\n' 'Name=Trader Workstation'
        printf '%s\n' 'Comment=Interactive Brokers Trader Workstation'
        printf '%s\n' "Exec=$out/bin/tws %u"
        printf '%s\n' "TryExec=$out/bin/tws"
        printf '%s\n' "Icon=$icon"
        printf '%s\n' 'Terminal=false'
        printf '%s\n' 'Categories=Office;Finance;'
        printf '%s\n' 'StartupNotify=true'
      } > "$out/share/applications/ib-tws.desktop"

      runHook postInstall
    '';

    meta = with lib; {
      description = "Interactive Brokers Trader Workstation (stable standalone)";
      homepage = "https://www.interactivebrokers.com/en/trading/tws.php";
      license = licenses.unfree;
      sourceProvenance = with sourceTypes; [binaryNativeCode];
      platforms = ["x86_64-linux"];
      mainProgram = "tws";
      maintainers = [];
    };
  };
in {
  environment.systemPackages = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
    ib-tws
  ];
}
