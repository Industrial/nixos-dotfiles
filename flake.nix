{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    for-all-systems.url = "github:Industrial/for-all-systems";
    for-all-systems.inputs.nixpkgs.follows = "nixpkgs";
    flake-checks.url = "github:Industrial/flake-checks";
    flake-checks.inputs.nixpkgs.follows = "nixpkgs";
    flake-devshells.url = "github:Industrial/flake-devshells";
    flake-devshells.inputs.nixpkgs.follows = "nixpkgs";
    flake-github-actions.url = "github:Industrial/flake-github-actions";
    flake-github-actions.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    nix-github-actions.url = "github:nix-community/nix-github-actions";
    nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";
    # nix-unit.url = "github:nix-community/nix-unit";
    # nix-unit.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {...}: let
    systems = ["x86_64-linux" "aarch64-darwin"];
    forAllSystems = inputs.for-all-systems.forAllSystems {
      nixpkgs = inputs.nixpkgs;
      inherit systems;
    };
  in {
    formatter =
      forAllSystems ({pkgs, ...}:
        pkgs.alejandra);

    githubActions = inputs.flake-github-actions.github-actions {
      inherit systems;
      checks = inputs.flake-checks.checks;
    } {inherit inputs;};

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
      pre-commit-check = inputs.git-hooks.lib.${system}.run {
        src = ./..;
        hooks = {
          # Nix
          alejandra.enable = true;
          deadnix.enable = true;
          flake-checker.enable = true;

          # Bash
          shellcheck.enable = true;
          beautysh.enable = true;

          # YAML
          check-yaml.enable = true;
          yamllint.enable = true;
          # yamlfmt.enable = true;

          # TOML
          check-toml.enable = true;
          taplo.enable = true;

          # Git
          check-merge-conflicts.enable = true;
          commitizen = {
            enable = true;
            stages = ["commit-msg"];
          };

          # TypeScript
          eslint.enable = true;

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

          # Unit Tests
          unit-tests = {
            enable = true;
            name = "Unit tests";
            entry = "nix run nixpkgs#nix-unit -- --flake .#tests";
            pass_filenames = false;
            stages = ["pre-push"];
          };
        };
      };
    });

    devShells = forAllSystems ({pkgs, ...}: {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          direnv
          jq
          pre-commit
        ];
      };
    });
  };
}
