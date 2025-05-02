{
  inputs = {
    # Nix Packages.
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };

    # Hardware Support.
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
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

    # Nix Flake Utilities.
    for-all-systems = {
      url = "github:Industrial/for-all-systems";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # Comin: Git Pull Based Deployment System.
    comin = {
      url = "github:nlewo/comin";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # NixVim
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # Cursor IDE
    cursor = {
      url = "github:omarcresp/cursor-flake/main";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # Nix VS Code Extensions.
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # Stylix.
    stylix = {
      url = "github:danth/stylix";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # Generate Kubernetes Configurations with Nix.
    kubenix = {
      url = "github:hall/kubenix";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # MicroVM
    microvm = {
      url = "github:astro/microvm.nix";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };

    # Nix Format.
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    # NixOS Anywhere
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    disko = {
      url = "github:nix-community/disko";
      inputs = {
        nixpkgs = {
	  follows = "nixpkgs";
	};
      };
    };
  };

  outputs = inputs @ {self, ...}: let
    systems = ["x86_64-linux"];

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

          nix-fmt = {
            enable = true;
            name = "Nix fmt";
            entry = "nix fmt";
            pass_filenames = false;
            stages = ["pre-commit"];
          };

          nix-flake-check = {
            enable = true;
            name = "Nix flake check";
            entry = "nix flake check";
            pass_filenames = false;
            stages = ["pre-commit"];
          };
        };
      });
  in {
    formatter =
      forAllSystems ({system, ...}:
        treefmtEval.${system}.config.build.wrapper);

    checks = forAllSystems ({system, ...}: {
      formatting = treefmtEval.${system}.config.build.check self;
    });

    githubActions = let
      supportedSystems = ["x86_64-linux"];
    in
      inputs.nix-github-actions.lib.mkGithubMatrix {
        checks = inputs.nixpkgs.lib.getAttrs supportedSystems self.checks;
      };

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

    nixosConfigurations =
      {}
      // (import ./hosts/drakkar.nix {inherit inputs;})
      // (import ./hosts/huginn.nix {inherit inputs;})
      // (import ./hosts/langhus.nix {inherit inputs;})
      // (import ./hosts/mimir.nix {inherit inputs;})
      // (import ./hosts/vm_database.nix {inherit inputs;})
      // (import ./hosts/vm_management.nix {inherit inputs;})
      // (import ./hosts/vm_target.nix {inherit inputs;})
      // (import ./hosts/vm_test.nix {inherit inputs;})
      // (import ./hosts/vm_tor.nix {inherit inputs;})
      // (import ./hosts/vm_web.nix {inherit inputs;});
  };
}
