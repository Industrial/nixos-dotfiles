{pkgs, ...}: {
  # https://devenv.sh/basics/
  env = {
    RUST_BACKTRACE = "1";
    RUST_LOG = "debug";
  };

  # https://devenv.sh/packages/
  packages = with pkgs; [
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

    # Development tools
    direnv
    git
    jq
    nixpkgs-fmt
    pre-commit
    treefmt
    commitizen
    nodejs

    # treefmt
    alejandra
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
    format.exec = "treefmt";
    commit.exec = "git-cz";
    test.exec = "bin/test";
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
        stages = ["pre-commit"];
        name = "treefmt";
        description = "Format code with treefmt";
        entry = "treefmt";
        pass_filenames = false;
        always_run = true;
      };
      commitizen = {
        enable = true;
        stages = ["commit-msg"];
      };
      nix-tests = {
        enable = true;
        stages = ["pre-commit"];
        name = "nix-tests";
        description = "Run Nix unit tests";
        entry = "bin/test";
        pass_filenames = false;
        always_run = true;
      };
      unit-tests = {
        enable = true;
        stages = ["pre-push"];
        name = "unit-tests";
        description = "Run unit tests";
        entry = "bin/test";
        pass_filenames = false;
        always_run = true;
      };
    };
  };
}
