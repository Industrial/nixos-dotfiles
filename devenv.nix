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
    nodePackages.npm
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
  ];

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
