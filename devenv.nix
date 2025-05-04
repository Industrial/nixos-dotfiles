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

    # treefmt
    treefmt
    deadnix
    alejandra
    actionlint
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
        settings = {
          # projectRootFile = "flake.nix";
          # formatters = {
          #   nix = {
          #     command = "alejandra";
          #     includes = ["*.nix"];
          #   };
          #   deadnix = {
          #     command = "deadnix";
          #     includes = ["*.nix"];
          #   };
          #   actionlint = {
          #     command = "actionlint";
          #     includes = [".github/workflows/*.yml"];
          #   };
          #   beautysh = {
          #     command = "beautysh";
          #     includes = ["*.sh"];
          #   };
          #   biome = {
          #     command = "biome";
          #     includes = ["*.{js,jsx,ts,tsx,json}"];
          #   };
          #   yamlfmt = {
          #     command = "yamlfmt";
          #     includes = ["*.{yml,yaml}"];
          #   };
          # };
        };
      };
    };
  };

  # # https://devenv.sh/pre-commit-hooks/
  # pre-commit.hooks = {
  #   # TOML
  #   check-toml.enable = true;
  #   taplo.enable = true;
  #   # Git
  #   check-merge-conflicts.enable = true;
  #   commitizen = {
  #     enable = true;
  #     stages = ["commit-msg"];
  #   };
  #   # Misc
  #   check-added-large-files.enable = true;
  #   check-case-conflicts.enable = true;
  #   check-executables-have-shebangs.enable = true;
  #   check-shebang-scripts-are-executable.enable = true;
  #   check-symlinks.enable = true;
  #   detect-aws-credentials.enable = true;
  #   detect-private-keys.enable = true;
  #   end-of-file-fixer.enable = true;
  #   fix-byte-order-marker.enable = true;
  #   forbid-new-submodules.enable = true;
  #   trim-trailing-whitespace.enable = true;
  #   # Nix
  #   nix-fmt = {
  #     enable = true;
  #     name = "Nix fmt";
  #     entry = "nix fmt";
  #     pass_filenames = false;
  #     stages = ["pre-commit"];
  #   };
  #   nix-flake-check = {
  #     enable = true;
  #     name = "Nix flake check";
  #     entry = "nix flake check";
  #     pass_filenames = false;
  #     stages = ["pre-commit"];
  #   };
  # };

  # # https://devenv.sh/ormatters/
  # formatters = {
  #   nix = {
  #     command = "alejandra";
  #     includes = ["*.nix"];
  #   };
  #   deadnix = {
  #     command = "deadnix";
  #     includes = ["*.nix"];
  #   };
  #   actionlint = {
  #     command = "actionlint";
  #     includes = [".github/workflows/*.yml"];
  #   };
  #   beautysh = {
  #     command = "beautysh";
  #     includes = ["*.sh"];
  #   };
  #   biome = {
  #     command = "biome";
  #     includes = ["*.{js,jsx,ts,tsx,json}"];
  #   };
  #   yamlfmt = {
  #     command = "yamlfmt";
  #     includes = ["*.{yml,yaml}"];
  #   };
  # };

  # # https://devenv.sh/tests/
  # enterTest = ''
  #   echo "Running tests"
  #   rust-version
  #   cargo-version
  # '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # See full reference at https://devenv.sh/reference/options/
}
