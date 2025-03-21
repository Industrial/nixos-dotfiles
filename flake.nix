{
  inputs = {
    # Nix Packages.
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };

    # Nix Flake Utilities.
    for-all-systems = {
      url = "github:Industrial/for-all-systems";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # Git Hooks.
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    # GitHub Actions.
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    # Nix Format.
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = inputs @ {self, ...}: let
    systems = ["x86_64-linux" "aarch64-darwin"];

    forAllSystems = inputs.for-all-systems.forAllSystems {
      nixpkgs = inputs.nixpkgs;
      inherit systems;
    };

    # Configure Treefmt
    treefmtEval = forAllSystems ({pkgs, ...}:
      inputs.treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";

        programs = {
          # Nix
          alejandra = {
            enable = true;
          };
          deadnix = {
            enable = true;
          };

          # Github Actions
          actionlint = {
            enable = true;
          };

          # Bash
          beautysh = {
            enable = true;
          };

          # TypeScript / JSON
          biome = {
            enable = true;
          };

          # YAML
          yamlfmt = {
            enable = true;
          };
        };
      });

    # We don't put this in the flake checks so that we can execute flake check
    # on pre-commit.
    pre-commit-check = forAllSystems ({system, ...}:
      inputs.git-hooks.lib.${system}.run {
        src = ./..;
        hooks = {
          # TODO: Move this to Treefmt.
          # TOML
          check-toml.enable = true;
          taplo.enable = true;

          # Git
          check-merge-conflicts.enable = true;
          commitizen = {
            enable = true;
            stages = ["commit-msg"];
          };

          # Misc
          check-added-large-files.enable = true;
          check-case-conflicts.enable = true;
          check-executables-have-shebangs.enable = true;
          check-shebang-scripts-are-executable.enable = true;
          check-symlinks.enable = true;
          detect-aws-credentials.enable = true;
          detect-private-keys.enable = true;
          end-of-file-fixer.enable = true;
          fix-byte-order-marker.enable = true;
          forbid-new-submodules.enable = true;
          trim-trailing-whitespace.enable = true;

          # Nix fmt and Flake Check
          format-and-check = {
            enable = true;
            name = "Fmt and Check";
            entry = "nix fmt && nix flake check";
            pass_filenames = false;
            stages = ["pre-commit"];
          };
        };
      });
  in {
    formatter =
      forAllSystems ({system, ...}:
        treefmtEval.${system}.config.build.wrapper);

    githubActions = let
      supportedSystems = ["x86_64-linux"];
    in
      inputs.nix-github-actions.lib.mkGithubMatrix {
        checks = inputs.nixpkgs.lib.getAttrs supportedSystems self.checks;
      };

    checks = forAllSystems ({system, ...}: {
      formatting = treefmtEval.${system}.config.build.check self;
    });

    devShells = forAllSystems ({
      pkgs,
      system,
    }: {
      default = pkgs.mkShell {
        shellHook = pre-commit-check.${system}.shellHook;
        buildInputs = pre-commit-check.${system}.enabledPackages;
        packages = with pkgs; [
          direnv
          jq
          pre-commit
        ];
      };
    });
  };
}
