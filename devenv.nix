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
    commit.exec = "git-cz";
  };

  tasks = {
    "chore:lint" = {
      description = "Lint the code";
      exec = "devenv shell treefmt --config-file treefmt.toml";
      before = ["ci:test"];
    };

    "ci:lint" = {
      description = "Lint the code";
      exec = "devenv shell treefmt --config-file treefmt.ci.toml";
      before = ["ci:test"];
    };
    "ci:test" = {
      description = "Run unit tests";
      exec = "devenv test";
    };
  };

  enterShell = ''
    echo "Welcome to the dotfiles development environment!"
    rust-version
    cargo-version
  '';

  git-hooks = {
    hooks = {
      commitizen = {
        enable = true;
        stages = ["commit-msg"];
      };
      lint = {
        enable = true;
        stages = ["pre-commit"];
        name = "lint";
        description = "Lint the code";
        pass_filenames = true;
        entry = "treefmt --config-file treefmt.toml";
      };
      test = {
        enable = true;
        stages = ["pre-push"];
        name = "nix-tests";
        description = "Run unit tests";
        entry = "devenv test";
        pass_filenames = false;
        always_run = true;
      };
    };
  };
}
