{pkgs, ...}: {
  # https://devenv.sh/basics/
  env = {
    RUST_BACKTRACE = "1";
    RUST_LOG = "debug";
    NIXPKGS_ALLOW_UNFREE = "1";
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

  tasks = {
    "chore:lint" = {
      description = "Lint the code";
      exec = "treefmt --config-file treefmt.toml";
      before = [];
    };

    "ci:lint" = {
      description = "Lint the code";
      exec = "devenv shell treefmt --config-file treefmt.ci.toml";
      before = [];
    };
  };

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
    };
  };
}
