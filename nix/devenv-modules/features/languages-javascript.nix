{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.local.features.languages-javascript;

  # Bun is pinned ahead of nixpkgs: devenv-nixpkgs/rolling and nixos-unstable both
  # still ship 1.3.13, so the 1.4 line has to come from the upstream release zips.
  # Asset names and layout follow nixpkgs' own bun derivation (baseline build on
  # x86_64-linux so the binary runs on pre-AVX2 hosts).
  defaultBunSources = {
    "x86_64-linux" = {
      asset = "bun-linux-x64-baseline";
      hash = "sha256-GE+0WV8NQBohfPfHjBvEMLqDMU2reouUgFurv3+nCX8=";
    };
    "aarch64-linux" = {
      asset = "bun-linux-aarch64";
      hash = "sha256-SxozLuhhmD65O8/m93D/+U4+MbLDiL2uo8jtNeWO7Q4=";
    };
    "x86_64-darwin" = {
      asset = "bun-darwin-x64";
      hash = "sha256-HQIRuPHcmRGCNEaHrRXnLuhvFUhFpff6R3mUzTQd2bA=";
    };
    "aarch64-darwin" = {
      asset = "bun-darwin-aarch64";
      hash = "sha256-xmnpf2Fk4cluBwF0jbmN+ndJKQjL2DlMdVcTSnNd44E=";
    };
  };

  bun = pkgs.bun.overrideAttrs (prev: {
    version = cfg.bunVersion;
    # `src` is derived from `passthru.sources` by the upstream derivation, which the
    # nixpkgs version-override heuristic cannot see; it is replaced just below.
    __intentionallyOverridingVersion = true;
    passthru =
      prev.passthru
      // {
        sources =
          lib.mapAttrs (
            _system: src:
              pkgs.fetchurl {
                url = "https://github.com/oven-sh/bun/releases/download/bun-v${cfg.bunVersion}/${src.asset}.zip";
                inherit (src) hash;
              }
          )
          cfg.bunSources;
      };
  });
in {
  options.local.features.languages-javascript = {
    enable = lib.mkEnableOption "JavaScript/TypeScript + Bun via devenv languages";

    bunVersion = lib.mkOption {
      type = lib.types.str;
      default = "1.4.0";
      description = "Bun release tag (without the `bun-v` prefix) to put on PATH.";
    };

    bunSources = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          asset = lib.mkOption {
            type = lib.types.str;
            description = "Release asset basename, without the `.zip` suffix.";
          };
          hash = lib.mkOption {
            type = lib.types.str;
            description = "SRI hash of the release asset.";
          };
        };
      });
      default = defaultBunSources;
      defaultText = lib.literalExpression "upstream oven-sh/bun release assets for the pinned bunVersion";
      description = "Per-system Bun release assets, keyed by Nix system double.";
    };
  };

  config = lib.mkIf cfg.enable {
    languages = {
      javascript = {
        enable = true;
        bun = {
          enable = true;
          package = bun;
        };
      };
      typescript.enable = true;
    };
  };
}
