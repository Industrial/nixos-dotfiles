# with-devenv — the devenv toolchain without entering `devenv shell`.
#
# Vendored by bin/drop-cursor-setup from ~/.dotfiles. Entering a devenv shell
# used to run the git-hooks task (`prek run -a`), and hook entries that
# re-entered the shell recursed without bound (2026-11-18: 16+ concurrent prek
# processes; prek's tree-wide stash reverted 153 dirty files).
#
# `config.local.withDevenv` is a store binary: config.packages on PATH and
# config.env exported, then `exec "$@"`. It evaluates nothing and runs no
# enterShell, tasks or hooks. Hook entries use it as
#   entry = "${config.local.withDevenv}/bin/with-devenv <cmd>";
# and enterShell links it at .devenv/with-devenv for bin/with-devenv.
#
# Deliberately not baked in:
#   - dotenv values (the store is world-readable). .env is sourced at run time.
#   - DEVENV_TASKS / DEVENV_TASK_FILE. They serialise the task graph, which
#     contains the hook entries, which reference this wrapper: infinite
#     recursion at eval. Hooks do not need them.
{
  pkgs,
  lib,
  config,
  ...
}: let
  dotenvNames = builtins.attrNames (config.dotenv.resolved or {});
  excluded = dotenvNames ++ ["DEVENV_TASKS" "DEVENV_TASK_FILE"];
  exportable = lib.filterAttrs (n: v:
    !(builtins.elem n excluded)
    && (builtins.isString v || builtins.isInt v || builtins.isPath v || lib.isDerivation v))
  config.env;
  withDevenv = pkgs.writeShellApplication {
    name = "with-devenv";
    runtimeInputs = config.packages;
    bashOptions = ["errexit" "pipefail"];
    text = ''
      ${lib.concatStrings (lib.mapAttrsToList (n: v: "export ${n}=${lib.escapeShellArg (toString v)}\n") exportable)}
      if [ -f "''${DEVENV_ROOT:-.}/.env" ]; then
        set -a
        # shellcheck disable=SC1091
        . "''${DEVENV_ROOT:-.}/.env"
        set +a
      fi
      exec "$@"
    '';
  };
in {
  options.local.withDevenv = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = "Store wrapper that runs a command with this devenv's packages and env, without entering the shell.";
  };

  config = {
    local.withDevenv = withDevenv;
    enterShell = lib.mkAfter ''
      ln -sfn ${withDevenv}/bin/with-devenv "$DEVENV_DOTFILE/with-devenv"
    '';
  };
}
