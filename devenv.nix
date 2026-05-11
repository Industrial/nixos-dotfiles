{
  inputs,
  pkgs,
  ...
}: let
  # Dotfiles Rust coreutils for devenv. `languages.rust` pulls in a stdenv whose PATH lists
  # pkgs.coreutils before `packages`, so we also prepend these in `enterShell` (see below).
  inherit (pkgs.lib) hiPrio;
  dotfilesCoreutils = [
    (hiPrio (pkgs.callPackage ./rust/tools/wc {}))
    (hiPrio (pkgs.callPackage ./rust/tools/cat {}))
    (hiPrio (pkgs.callPackage ./rust/tools/sort {}))
    (hiPrio (pkgs.callPackage ./rust/tools/ls {}))
    (hiPrio (pkgs.callPackage ./rust/tools/head {}))
    (hiPrio (pkgs.callPackage ./rust/tools/rev {}))
  ];
  dotfilesCoreutilsBin = pkgs.lib.makeBinPath dotfilesCoreutils;
in {
  # https://devenv.sh/basics/
  env = {
    RUST_BACKTRACE = "1";
    RUST_LOG = "debug";
    NIXPKGS_ALLOW_UNFREE = "1";
  };

  # https://devenv.sh/packages/
  packages =
    dotfilesCoreutils
    ++ (with pkgs; [
      # AI
      inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.beads

      # Nix
      nix-unit
      namaka
      nixt

      # Rust toolchain
      rustc
      cargo
      rustfmt
      clippy
      rust-analyzer

      # System dependencies for Wayland compositor
      systemd
      libinput

      # Development tools
      direnv
      git
      gh
      jq
      nixpkgs-fmt
      pre-commit
      treefmt
      commitizen
      nodejs
      slumber
      lazysql

      # treefmt
      alejandra
      actionlint
      deadnix
      beautysh
      biome
      yamlfmt
      taplo
      rustfmt
      vulnix
    ]);

  # Prepend so `which cat` / `which wc` resolve to rust_* (Rust stdenv puts coreutils earlier in PATH).
  enterShell = ''
    export PATH="${dotfilesCoreutilsBin}:$PATH"
  '';

  # https://devenv.sh/languages/
  languages = {
    rust = {
      enable = true;
      channel = "stable";
      components = ["rustfmt" "clippy" "rust-analyzer"];
    };

    javascript = {
      enable = true;
      package = pkgs.nodejs;
      bun = {
        enable = true;
        package = pkgs.bun;
      };
    };
  };

  scripts = {
    prek-install = {
      exec = ''
        ${pkgs.prek}/bin/prek install -q --overwrite -c "$DEVENV_ROOT/.pre-commit-config.yaml"
        # `core.hooksPath` (e.g. beads → `.beads/hooks`) is where prek installs. If that
        # directory previously held a PyPI `pre-commit` shim, prek renames it to `*.legacy`
        # and still runs it first; that legacy binary prints "migration mode" and exits
        # non-zero, blocking commits even when commitizen passes. Drop stale legacy shims.
        if cd "$DEVENV_ROOT" && git rev-parse --git-dir >/dev/null 2>&1; then
          HOOKS_DIR=$(git rev-parse --git-path hooks 2>/dev/null) || true
          if [ -n "$HOOKS_DIR" ] && [ -d "$HOOKS_DIR" ]; then
            rm -f "$HOOKS_DIR"/*.legacy
          fi
        fi
      '';
    };
  };

  tasks = {
    "devenv:git-hooks:install" = pkgs.lib.mkForce {
      after = ["devenv:files"];
      before = ["devenv:enterShell"];
      exec = ''
        prek-install
      '';
    };
  };

  git-hooks = {
    hooks = {
      deepsec = {
        enable = true;
        stages = ["pre-push"];
        name = "deepsec";
        description = "Run deepsec process on outgoing commits; blocks push on findings";
        pass_filenames = false;
        always_run = true;
        entry = "devenv shell -- bin/git-hooks/deepsec-pre-push";
      };
    };
  };
}
