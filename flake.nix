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
    forAllSystems = import ./lib/forAllSystems.nix inputs.nixpkgs;
  in {
    githubActions = import ./github-actions.nix {inherit self inputs;};
    nixosConfigurations = {} // (import ./hosts/langhus.nix {inherit inputs;});
    darwinConfigurations = {} // (import ./hosts/smithja.nix {inherit inputs;});

    tests = forAllSystems ["x86_64-linux"] ({
      system,
      pkgs,
    }:
      import ./tests.nix {inherit inputs system pkgs;});

    checks = forAllSystems inputs.nixpkgs.lib.systems.flakeExposed ({
      system,
      pkgs,
    }:
      import ./checks.nix {inherit inputs system pkgs;});

    devShells = forAllSystems inputs.nixpkgs.lib.systems.flakeExposed ({
      system,
      pkgs,
    }:
      import ./devshells.nix {inherit self system pkgs;});
  };
}
