{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.local.features.program-moon;
  # Moon from GitHub releases (x86_64-linux). See https://moonrepo.dev/docs/install
  moon = pkgs.stdenv.mkDerivation {
    pname = "moon-cli";
    version = "2.5.0";
    src = pkgs.fetchurl {
      url = "https://github.com/moonrepo/moon/releases/download/v2.5.0/moon_cli-x86_64-unknown-linux-gnu.tar.xz";
      sha256 = "0fvxx7jr67xp95w8kyxky7caq8rf4dimrprr6wish3nicnb6vp65";
    };
    nativeBuildInputs = [pkgs.autoPatchelfHook];
    buildInputs = [pkgs.stdenv.cc.cc.lib];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -m755 moon $out/bin/moon
      runHook postInstall
    '';
    meta = {
      description = "Moon CLI (moonrepo)";
      homepage = "https://moonrepo.dev";
      license = pkgs.lib.licenses.mit;
      platforms = pkgs.lib.platforms.linux;
    };
  };
in {
  options.local.features.program-moon.enable = lib.mkEnableOption "Moon task runner CLI (pinned release)";

  config = lib.mkIf cfg.enable {
    packages = [moon];

    scripts.moon-sync.exec = ''
      moon sync
    '';

    enterShell = lib.mkBefore ''
      moon-sync
    '';
  };
}
