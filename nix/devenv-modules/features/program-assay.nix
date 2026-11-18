{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.local.features.program-assay;
  version = cfg.version;
  assay-release = pkgs.stdenv.mkDerivation {
    pname = "assay";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://github.com/Industrial/assay/releases/download/v${version}/assay-x86_64-unknown-linux-gnu.tar.gz";
      hash = cfg.releaseHash;
    };
    sourceRoot = "assay-x86_64-unknown-linux-gnu";
    nativeBuildInputs = [pkgs.autoPatchelfHook];
    buildInputs = [pkgs.stdenv.cc.cc.lib];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -m755 assay $out/bin/assay
      runHook postInstall
    '';
    meta = {
      description = "Assay Nix unit-test runner (pinned GitHub release)";
      homepage = "https://github.com/Industrial/assay";
      license = pkgs.lib.licenses.mit;
      platforms = ["x86_64-linux"];
    };
  };
  assay-flake = pkgs.writeShellApplication {
    name = "assay";
    runtimeInputs = [pkgs.nix];
    text = ''
      exec nix --extra-experimental-features "nix-command flakes" run "github:Industrial/assay/v${version}" -- "$@"
    '';
  };
  assay =
    if cfg.releaseHash != null
    then assay-release
    else assay-flake;
in {
  options.local.features.program-assay = {
    enable = lib.mkEnableOption "Assay CLI for Nix module unit tests";
    version = lib.mkOption {
      type = lib.types.str;
      default = "0.3.0";
      description = "Assay version tag / release to pin";
    };
    releaseHash = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      # sha256 of assay-x86_64-unknown-linux-gnu.tar.gz from github:Industrial/assay v0.3.0
      default = "sha256-jQx8LR8nA6mFbM1nvxl2vQC6fvwGgtEEezMF9sMCVGQ=";
      description = "SRI hash of the linux-gnu release tarball; null uses nix run wrapper";
    };
    dogfood = lib.mkEnableOption "assay-dogfood helper script" // {default = true;};
  };

  config = lib.mkIf cfg.enable {
    packages = [assay pkgs.nix];

    scripts.assay-dogfood = lib.mkIf cfg.dogfood {
      exec = ''
        set -euo pipefail
        root="''${DEVENV_ROOT:-.}"
        if [[ -n "''${ASSAY_DOGFOOD_SUITE:-}" ]]; then
          target="$ASSAY_DOGFOOD_SUITE"
        elif [[ -d "$root/nix" && -f "$root/nix/default.assay.nix" ]]; then
          target="$root/nix"
        elif [[ -d "$root/.cursor/nix" && -f "$root/.cursor/nix/default.assay.nix" ]]; then
          target="$root/.cursor/nix"
        else
          echo "assay-dogfood: missing nix/ or .cursor/nix assay suites" >&2
          exit 1
        fi
        assay run "$target"
      '';
    };
  };
}
