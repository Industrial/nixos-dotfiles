# with-devenv — the devenv shell's environment without entering `devenv shell`.
#
# Vendored by bin/drop-cursor-setup from ~/.dotfiles. Entering a devenv shell
# used to run the git-hooks task (`prek run -a`), and hook entries that
# re-entered the shell recursed without bound (2026-11-18: 16+ concurrent prek
# processes; prek's tree-wide stash reverted 153 dirty files).
#
# `config.local.withDevenv` is a store binary. Hook entries use it as
#   entry = "${config.local.withDevenv}/bin/with-devenv <cmd>";
# and bin/with-devenv reaches it through the .devenv/with-devenv link.
#
# WHAT IT PROVIDES, in order:
#   1. config.packages on PATH and config.env exported (baked at build time).
#   2. The SNAPSHOT: every shell entry, as its last step, writes the shell's
#      complete exported environment to .devenv/with-devenv.env (mode 600).
#      That carries what (1) cannot: variables enterShell exports, and what the
#      shell's setup hooks derive from the profile (XDG_DATA_DIRS for fonts,
#      PKG_CONFIG_PATH, compiler flags...). Without it, redox's design tests
#      lost their font, because devenv.nix provides it as a package that
#      fontconfig finds only through the shell's XDG_DATA_DIRS. So a hook
#      sees what `devenv shell` would give it. The snapshot is taken from a
#      real shell, so it is only as fresh as the last shell entry; a fresh
#      clone with no snapshot gets (1) alone.
#   3. The repo's .env, sourced at run time.
#
# Deliberately not baked into the store (world-readable): dotenv values (3
# covers them). Left out of the snapshot: git's own variables (a hook runs
# inside a git process that sets GIT_DIR, GIT_INDEX_FILE...), the terminal and
# session (TERM, SSH_*, DISPLAY, DBUS...), and per-process state (PWD, SHLVL).
# Left out of (1): DEVENV_TASKS / DEVENV_TASK_FILE, which serialise the task
# graph, which contains the hook entries, which reference this wrapper:
# infinite recursion at eval. Hooks do not need them.
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
  # variables a snapshot must never carry into another process
  volatile = lib.concatStringsSep "|" [
    "PWD"
    "OLDPWD"
    "SHLVL"
    "_"
    "HOME"
    "USER"
    "LOGNAME"
    "SHELL"
    "PS1"
    "PROMPT_COMMAND"
    "TERM"
    "TERM_[A-Z_]+"
    "COLORTERM"
    "TERMINFO"
    "SSH_[A-Z_]+"
    "DISPLAY"
    "WAYLAND_DISPLAY"
    "XDG_RUNTIME_DIR"
    "XDG_SESSION_[A-Z_]+"
    "DBUS_SESSION_BUS_ADDRESS"
    "TMUX"
    "TMUX_PANE"
    "ZELLIJ[A-Z_]*"
    "GIT_[A-Z_]+"
    "CLAUDE[A-Z_]*"
    "PASEO[A-Z_]*"
    "DIRENV_[A-Z_]+"
    "IN_NIX_SHELL"
    "DEVENV_IN_SHELL"
  ];
  withDevenv = pkgs.writeShellApplication {
    name = "with-devenv";
    runtimeInputs = config.packages;
    bashOptions = ["errexit" "pipefail"];
    text = ''
      ${lib.concatStrings (lib.mapAttrsToList (n: v: "export ${n}=${lib.escapeShellArg (toString v)}\n") exportable)}
      snapshot="''${DEVENV_DOTFILE:-''${DEVENV_ROOT:-.}/.devenv}/with-devenv.env"
      if [ -r "$snapshot" ]; then
        # shellcheck disable=SC1090
        . "$snapshot"
      fi
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
    description = "Store wrapper that runs a command with this devenv shell's environment, without entering the shell.";
  };

  config = {
    local.withDevenv = withDevenv;
    # Last of all enterShell work, so the snapshot sees every export before it.
    enterShell = lib.mkOrder 2000 ''
      ln -sfn ${withDevenv}/bin/with-devenv "$DEVENV_DOTFILE/with-devenv"
      (
        umask 077
        export -p | grep -v -E '^declare -x (${volatile})(=|$)' > "$DEVENV_DOTFILE/with-devenv.env.tmp" &&
          mv -f "$DEVENV_DOTFILE/with-devenv.env.tmp" "$DEVENV_DOTFILE/with-devenv.env"
      ) || true
    '';
  };
}
