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
    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {self, ...}: let
    forAllSystems = inputs.for-all-systems.forAllSystems {nixpkgs = inputs.nixpkgs;};
  in {
    githubActions = inputs.flake-github-actions.github-actions {
      systems = ["x86_64-linux" "aarch64-darwin"];
      checks = inputs.flake-checks.checks;
    } {inherit inputs;};

    tests =
      inputs.for-all-systems.forAllSystems {
        nixpkgs = inputs.nixpkgs;
        systems = ["x86_64-linux"];
      } ({
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

    checks =
      forAllSystems ({system, ...}:
        inputs.flake-checks.checks {inherit inputs system;});

    devShells = forAllSystems ({
      system,
      pkgs,
    }:
      inputs.flake-devshells.devshells {packages = with pkgs; [direnv pre-commit];} {inherit self system pkgs;});
  };
}
