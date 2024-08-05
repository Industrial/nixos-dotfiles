{
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # For All Systems
    for-all-systems.url = "github:Industrial/for-all-systems";
    for-all-systems.inputs.nixpkgs.follows = "nixpkgs";

    # Nix Git Hooks
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";

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

    # # NixVim
    # nixvim.url = "https://flakehub.com/f/nix-community/nixvim/0.1.*.tar.gz";
    # nixvim.inputs.nixpkgs.follows = "nixpkgs";

    # Nix VSCode Extensions
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {...}: let
    forAllSystems = inputs.for-all-systems.forAllSystems {nixpkgs = inputs.nixpkgs;};
  in {
    githubActions = import ../../common/github-actions.nix {inherit inputs;};

    nixosConfigurations = {} // (import ../../common/hosts/langhus.nix {inherit inputs;});

    tests =
      inputs.for-all-systems.forAllSystems {
        nixpkgs = inputs.nixpkgs;
        systems = ["x86_64-linux"];
      } ({
        system,
        pkgs,
      }:
        import ../../common/tests.nix {inherit inputs system pkgs;});

    checks = forAllSystems ({
      system,
      pkgs,
    }:
      import ../../common/checks.nix {inherit inputs system pkgs;});

    # devShells = forAllSystems ({
    #   system,
    #   pkgs,
    # }:
    #   import ../../common/devshells.nix {inherit self system pkgs;});
  };
}
