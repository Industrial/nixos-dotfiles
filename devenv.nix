# Consumer devenv: enable shared `.cursor/nix` features; keep project-only packages/hooks here.
{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  assayPkgs = inputs.assay.packages.${system};

  # THE SHELL'S TOOLCHAIN WITHOUT ENTERING THE SHELL.
  #
  # Git hooks used to run `devenv shell -- <cmd>`, and entering a devenv shell
  # runs the git-hooks task (`prek run -a`), whose hooks entered the shell
  # again: unbounded recursion. On 2026-11-18 it reached 16+ concurrent prek
  # processes, and prek's tree-wide stash/restore reverted 153 dirty files.
  #
  # `with-devenv <cmd>` gives <cmd> what the shell would: config.packages on
  # PATH and config.env exported. It is a plain store binary, so starting it
  # evaluates nothing and runs no enterShell, no tasks and no hooks. Two
  # deliberate gaps:
  #   - enterShell side effects do not run. Here that is only install-git-hooks.
  #   - dotenv values are NOT baked in, because the store is world-readable. The
  #     repo's .env is sourced at run time instead, if it exists.
  # DEVENV_TASKS / DEVENV_TASK_FILE are left out too. They serialise the task
  # graph, which contains the git-hooks tasks, which contain the hook entries
  # below, which reference this wrapper: infinite recursion at eval time. A hook
  # has no use for the shell's task graph anyway.
  dotenvNames = builtins.attrNames (config.dotenv.resolved or {});
  excluded = dotenvNames ++ ["DEVENV_TASKS" "DEVENV_TASK_FILE"];
  exportable = lib.filterAttrs (n: v:
    !(builtins.elem n excluded)
    && (builtins.isString v || builtins.isInt v || builtins.isPath v || lib.isDerivation v))
  config.env;
  withDevenv = pkgs.writeShellApplication {
    name = "with-devenv";
    runtimeInputs = config.packages;
    # Exported values may legitimately expand unset variables; allow it.
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
  hookCmd = cmd: "${withDevenv}/bin/with-devenv ${cmd}";
in {
  imports = [./.cursor/nix];

  name = "dotfiles";

  # Shared programs / packages from Industrial/cursor-setup (.cursor/nix).
  # blaze is the default Rust build/check/run/test command (see moon.yml). It
  # ships its own toolchain, so languages-rust and packages-rust-dev stay on:
  # rust-analyzer, clippy, rustfmt and the cargo-* helpers are still cargo's.
  cursor.features.program-blaze.enable = true;
  cursor.features.program-moon.enable = true;
  cursor.features.program-lean-ctx.enable = true;
  cursor.features.program-roam-code.enable = false;
  cursor.features.program-roam-code-pypi.enable = true;
  cursor.features.program-claude-code.enable = true;
  cursor.features.program-maestro.enable = true;
  cursor.features.program-context7.enable = true;
  cursor.features.program-omniroute.enable = true;
  cursor.features.program-assay.enable = true;
  cursor.features.packages-base.enable = true;
  cursor.features.packages-formatters.enable = true;
  cursor.features.packages-rust-dev.enable = true;
  cursor.features.languages-javascript.enable = true;
  cursor.features.languages-rust.enable = true;
  cursor.features.dotenv.enable = true;
  cursor.features.git-hooks-prek.enable = true;

  # Project-only packages (not in shared features).
  packages = with pkgs; [
    inputs.definitively.packages.${system}.definitively

    # Assay workspace companions (CLI itself comes from program-assay).
    assayPkgs.nixq
    assayPkgs.nixdrv
    assayPkgs.nixfetch
    assayPkgs.nixstore
    nix-unit
    namaka
    nixt

    # Host / NixOS tooling extras
    systemd
    libinput

    llvmPackages.llvm
  ];

  env = {
    RUST_BACKTRACE = "1";
    RUST_LOG = "debug";
    NIXPKGS_ALLOW_UNFREE = "1";
    LLVM_COV = "${pkgs.llvmPackages.llvm}/bin/llvm-cov";
    LLVM_PROFDATA = "${pkgs.llvmPackages.llvm}/bin/llvm-profdata";
  };

  scripts = {
    format.exec = "moon run dotfiles:format";
    # Dotfiles-appropriate targets for git-hooks-prek entry points.
    pre-push.exec = ''
      unset GIT_INDEX_FILE GIT_PREFIX || true
      moon run dotfiles:test
    '';
    pre-commit.exec = ''
      unset GIT_INDEX_FILE GIT_PREFIX || true
      moon run dotfiles:test --affected
    '';
  };

  # Project-specific hooks (deepsec + full-repo assay).
  git-hooks.hooks = {
    deepsec = {
      enable = true;
      stages = ["pre-push"];
      name = "deepsec";
      description = "Run deepsec process on outgoing commits; blocks push on findings";
      pass_filenames = false;
      always_run = true;
      entry = hookCmd "bin/git-hooks/deepsec-pre-push";
    };
    moon-test = {
      enable = true;
      stages = ["pre-commit"];
      name = "moon test (affected)";
      description = "Run moon :test --affected on changed files";
      pass_filenames = false;
      always_run = true;
      entry = hookCmd "moon run dotfiles:test --affected";
    };
    moon-coverage = {
      enable = false;
    };

    # The shared git-hooks-prek feature names its pre-commit/pre-push scripts
    # bare, so they resolve only inside an entered shell. Git runs hooks from
    # wherever it was invoked (an agent, Paseo, an editor), so give them the
    # shell's toolchain explicitly.
    pre-commit.entry = lib.mkForce (hookCmd "pre-commit");
    pre-push.entry = lib.mkForce (hookCmd "pre-push");
  };

  # ENTERING THE SHELL MUST NOT RUN THE HOOKS. devenv's git-hooks integration
  # declares `devenv:git-hooks:run` (`prek run -a`) as `before
  # devenv:enterTest`, and devenv runs `devenv:enterShell` in `--mode all`, which
  # also pulls in enterShell's dependents: enterTest, and through it the hook
  # run. So every `devenv shell`, interactive or `-- <cmd>`, ran every hook
  # across the repo, and prek's tree-wide stash ran with it. Hooks belong to git
  # (commit, push), so cut that edge. `devenv test` no longer runs them either;
  # `prek run -a` does that on demand.
  tasks."devenv:git-hooks:run".before = lib.mkForce [];

  # A stable path to the wrapper for agents and scripts outside the shell:
  # `.devenv/with-devenv <cmd>`, or `bin/with-devenv <cmd>`, which falls back
  # to `devenv shell --` until the link exists.
  enterShell = lib.mkAfter ''
    ln -sfn ${withDevenv}/bin/with-devenv "$DEVENV_DOTFILE/with-devenv"
  '';
}
