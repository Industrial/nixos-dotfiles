{
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";

    # Nix Git Hooks
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";

    # Nix GitHub Actions
    nix-github-actions.url = "github:nix-community/nix-github-actions";
    nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";

    # Nix Unit
    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";

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
    forAllSystems = inputs.nixpkgs.lib.genAttrs inputs.nixpkgs.lib.systems.flakeExposed;
  in {
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
          system = "x86_64-linux";
          config = {
            allowUnfree = true;
          };
        };
      };
    };

    githubActions = inputs.nix-github-actions.lib.mkGithubMatrix {
      checks = inputs.nixpkgs.lib.getAttrs ["x86_64-linux" "aarch64-darwin"] self.checks;
    };

    nixosConfigurations = {} // (import ./hosts/langhus.nix {inherit inputs;});
    darwinConfigurations = {} // (import ./hosts/smithja.nix {inherit inputs;});

    checks = forAllSystems (system: let
      pkgs = import inputs.nixpkgs {inherit system;};
    in {
      pre-commit-check = import ./checks/pre-commit.nix {inherit inputs system pkgs;};
    });

    devShells = forAllSystems (system: let
      pkgs = import inputs.nixpkgs {inherit system;};
    in {
      default = pkgs.mkShell {
        inherit (self.checks.${system}.pre-commit-check) shellHook;
        buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
        inputsFrom = [];
        packages = with pkgs; [
          direnv
        ];
      };
    });
  };
}
