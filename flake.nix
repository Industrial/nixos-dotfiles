{
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Flake Parts
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Nix Git Hooks
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";

    # Nix GitHub Actions
    nix-github-actions.url = "github:nix-community/nix-github-actions";
    nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";

    # Nix Unit
    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
    nix-unit.inputs.flake-parts.follows = "flake-parts";

    # Nix Darwin
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # MicroVM
    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    # NixVim
    nixvim.url = "https://flakehub.com/f/nix-community/nixvim/0.1.*.tar.gz";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    # Nix VSCode Extensions
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";

    # Stylix
    stylix.url = "https://flakehub.com/f/danth/stylix/0.1.*.tar.gz";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    # Cryptpad
    cryptpad.url = "https://flakehub.com/f/michaelshmitty/cryptpad/2.2.0.tar.gz";
    cryptpad.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs @ {self, ...}: let
    githubActionsSystems = ["x86_64-linux" "x86_64-darwin"];
  in
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      flake = {
        tests = let
          settings = {
            hostname = "testhostname";
            stateVersion = "24.05";
            system = "x86_64-linux";
            hostPlatform = {
              system = "x86_64-linux";
            };
            userdir = "/Users/test";
            useremail = "test@test.com";
            userfullname = "Chadster McChaddington";
            username = "test";
          };
        in {
          features = import ./features/tests.nix {
            inherit inputs settings;
            pkgs = import inputs.nixpkgs {
              # TODO: How can I abstract away the system with flake-parts?
              system = "x86_64-linux";
              config = {
                allowUnfree = true;
              };
            };
          };
        };

        # Creates a GitHub Actions matrix for the checks.
        githubActions = inputs.nix-github-actions.lib.mkGithubMatrix {
          # Only run checks on the systems that we support on GitHub Actions.
          checks = inputs.nixpkgs.lib.getAttrs githubActionsSystems self.checks;
        };

        nixosConfigurations = {} // (import ./hosts/langhus.nix {inherit inputs;});
        darwinConfigurations = {} // (import ./hosts/smithja.nix {inherit inputs;});
      };

      perSystem = {
        system,
        pkgs,
        ...
      }: let
      in {
        formatter = pkgs.alejandra;

        checks = {
          pre-commit-check = import ./checks/pre-commit.nix {inherit inputs system pkgs;};
          tests = import ./checks/tests.nix {inherit inputs self system pkgs;};
        };

        devShells = {
          default = pkgs.mkShell {
            inherit (self.checks.${system}.pre-commit-check) shellHook;
            buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
            inputsFrom = [];
            packages = with pkgs; [
              direnv
            ];
          };
        };
      };
    };
}
