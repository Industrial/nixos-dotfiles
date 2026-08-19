# Consumer devenv: enable shared `.cursor/nix` features; keep project-only packages/hooks here.
{
  inputs,
  pkgs,
  lib,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  pkgs-unstable = import inputs.nixpkgs-unstable {inherit system;};
  assayPkgs = inputs.assay.packages.${system};
  nixHash = pkgs.callPackage ./rust/tools/nix-hash {
    rustc = pkgs-unstable.rustc;
    cargo = pkgs-unstable.cargo;
  };
in {
  imports = [./.cursor/nix];

  name = "dotfiles";

  # Shared programs / packages from Industrial/cursor-setup (.cursor/nix).
  cursor.features.program-moon.enable = true;
  cursor.features.program-lean-ctx.enable = true;
  cursor.features.program-roam-code.enable = false;
  cursor.features.program-roam-code-pypi.enable = true;
  cursor.features.program-maestro.enable = true;
  cursor.features.program-serena.enable = true;
  cursor.features.program-context7.enable = true;
  cursor.features.program-omniroute.enable = true;
  cursor.features.program-hermes.enable = true;
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
    nixHash
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
    format.exec = "treefmt";
    # Dotfiles-appropriate targets for git-hooks-prek entry points.
    pre-push.exec = ''
      unset GIT_INDEX_FILE GIT_PREFIX || true
      assay run .
    '';
    pre-commit.exec = ''
      unset GIT_INDEX_FILE GIT_PREFIX || true
      assay run .
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
      name = "moon test (assay)";
      description = "Run moon :test (assay across the repo)";
      pass_filenames = false;
      always_run = true;
      entry = "devenv shell -- assay run .";
    };
    moon-coverage = {
      enable = false;
    };
  };
}
