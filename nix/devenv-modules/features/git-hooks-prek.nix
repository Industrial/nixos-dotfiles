{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.local.features.git-hooks-prek;
in {
  options.local.features.git-hooks-prek = {
    enable = lib.mkEnableOption "prek git-hooks (commitizen + pre-commit/pre-push scripts)";
    configFile = lib.mkOption {
      type = lib.types.str;
      default = ".pre-commit-config.yaml";
      description = "prek config path relative to DEVENV_ROOT";
    };
  };

  config = lib.mkIf cfg.enable {
    git-hooks = {
      package = pkgs.prek;

      default_stages = [
        "pre-push"
        "commit-msg"
      ];

      hooks = {
        commitizen.enable = true;

        pre-commit = {
          enable = true;
          name = "pre-commit";
          entry = "pre-commit";
          stages = ["pre-commit"];
          pass_filenames = false;
          always_run = true;
          language = "system";
          verbose = true;
        };

        pre-push = {
          enable = true;
          name = "pre-push";
          entry = "pre-push";
          stages = ["pre-push"];
          pass_filenames = false;
          always_run = true;
          language = "system";
          verbose = true;
        };
      };
    };

    # Force-install so shims are not left in migration mode (hooks pass but commit/push abort).
    scripts.install-git-hooks.exec = ''
      set -euo pipefail

      if [[ -n "''${CI:-}" ]]; then
        exit 0
      fi

      if git config --get core.hooksPath >/dev/null 2>&1; then
        exit 0
      fi

      root="''${DEVENV_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
      cd "$root"

      cfg="$root/${cfg.configFile}"
      if [[ ! -f "$cfg" ]]; then
        exit 0
      fi

      hooks_dir="$root/.git/hooks"
      if [[ -d "$hooks_dir" ]]; then
        rm -f \
          "$hooks_dir/pre-commit.legacy" \
          "$hooks_dir/pre-commit.old" \
          "$hooks_dir/pre-commit-user" \
          "$hooks_dir/pre-push.old" 2>/dev/null || true
      fi

      exec prek install -f -c "$cfg" \
        -t pre-commit \
        -t commit-msg \
        -t pre-push
    '';

    enterShell = lib.mkAfter ''
      install-git-hooks
    '';
  };
}
