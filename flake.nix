{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };
    for-all-systems = {
      url = "github:Industrial/for-all-systems";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
    flake-checks = {
      url = "github:Industrial/flake-checks";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
    flake-devshells = {
      url = "github:Industrial/flake-devshells";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    flake-github-actions = {
      url = "github:Industrial/flake-github-actions";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
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

          # Unit Tests
          unit-tests = {
            enable = true;
            name = "Unit tests";
            entry = "nix run nixpkgs#nix-unit -- --flake .#tests";
            pass_filenames = false;
            stages = ["pre-push"];
          };
        };
      });
  in {
    formatter =
      forAllSystems ({system, ...}:
        treefmtEval.${system}.config.build.wrapper);

    githubActions = forAllSystems ({system, ...}:
      inputs.flake-github-actions.github-actions {
        inherit systems;
        checks = self.checks.${system};
      } {inherit inputs;});

    tests = forAllSystems ({
      system,
      pkgs,
    }: let
      settings = {
        inherit system;
        hostname = "testhostname";
        stateVersion = "24.05";
        hostPlatform = {
          inherit system;
        };
        userdir = "/Users/test";
        useremail = "test@test.com";
        userfullname = "Chadster McChaddington";
        username = "test";
      };
    in {
      features = import ./features/tests.nix {
        inherit inputs settings pkgs;
      };
    });

    # tests =
    #   inputs.for-all-systems.forAllSystems {
    #     nixpkgs = inputs.nixpkgs;
    #     systems = ["x86_64-linux"];
    #   } ({
    #     system,
    #     pkgs,
    #   }: let
    #     settings = {
    #       inherit system;
    #       hostname = "testhostname";
    #       stateVersion = "24.05";
    #       hostPlatform = {
    #         inherit system;
    #       };
    #       userdir = "/Users/test";
    #       useremail = "test@test.com";
    #       userfullname = "Chadster McChaddington";
    #       username = "test";
    #     };
    #   in {
    #     features = import ./features/tests.nix {
    #       inherit inputs settings pkgs;
    #     };
    #   });

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
