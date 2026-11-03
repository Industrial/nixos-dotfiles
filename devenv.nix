# Consumer devenv: enable shared `.cursor/nix` features; keep project-only packages/hooks here.
{
  inputs,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  assayPkgs = inputs.assay.packages.${system};
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
    slumber
    lazysql

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
      entry = "devenv shell -- bin/git-hooks/deepsec-pre-push";
    };
    moon-test = {
      enable = true;
      stages = ["pre-commit"];
      name = "moon test (affected)";
      description = "Run moon :test --affected on changed files";
      pass_filenames = false;
      always_run = true;
      entry = "devenv shell -- moon run dotfiles:test --affected";
    };
    moon-coverage = {
      enable = false;
    };
  };
}
