{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  # https://devenv.sh/basics/
  env = {
    RUST_BACKTRACE = "1";
    RUST_LOG = "debug";
  };

  # https://devenv.sh/packages/
  packages = with pkgs; [
    # Rust toolchain
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer

    # Development tools
    direnv
    git
    jq
    nixpkgs-fmt
    alejandra
    pre-commit
    treefmt
    commitizen
    nodejs

    # treefmt
    actionlint
    deadnix
    beautysh
    biome
    yamlfmt
    taplo
    rustfmt
  ];

  # https://devenv.sh/languages/
  languages = {
    rust = {
      enable = true;
      channel = "stable";
      components = ["rustfmt" "clippy" "rust-analyzer"];
    };
  };

  # https://devenv.sh/scripts/
  scripts = {
    rust-version.exec = "rustc --version";
    cargo-version.exec = "cargo --version";
    commit.exec = "git-cz";
  };

  enterShell = ''
    echo "Welcome to the dotfiles development environment!"
    rust-version
    cargo-version
  '';

  git-hooks = {
    hooks = {
      treefmt = {
        enable = true;
      };
      commitizen = {
        enable = true;
        stages = ["commit-msg"];
      };
    };
  };
}
