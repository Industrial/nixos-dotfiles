{
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";

    # For All Systems
    for-all-systems.url = "github:Industrial/for-all-systems";
    for-all-systems.inputs.nixpkgs.follows = "nixpkgs";

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
  };
  outputs = inputs @ {self, ...}: let
    forAllSystems = inputs.for-all-systems.forAllSystems {nixpkgs = inputs.nixpkgs;};
  in {
    githubActions = inputs.nix-github-actions.lib.mkGithubMatrix {
      # checks = {
      #   # "x86_64-linux" = {
      #   #   hello = inputs.nixpkgs.legacyPackages.x86_64-linux.hello;
      #   # };
      #   "x86_64-linux" = import ./checks.nix {
      #     inherit inputs;
      #     system = "x86_64-linux";
      #   };
      # };

      checks =
        inputs.for-all-systems.forAllSystems {
          nixpkgs = inputs.nixpkgs;
          systems = ["x86_64-linux" "aarch64-darwin"];
        } ({
          system,
          pkgs,
        }:
          import ./checks.nix {inherit inputs system pkgs;});
    };

    # githubActions = {
    #   matrix = inputs.nix-github-actions.lib.mkGithubMatrix {
    #     checks = {
    #       "x86_64-linux" = import ./checks.nix {
    #         inherit inputs;
    #         system = "x86_64-linux";
    #       };
    #     };
    #     # inputs.for-all-systems.forAllSystems {
    #     #   nixpkgs = inputs.nixpkgs;
    #     #   systems = ["x86_64-linux" "aarch64-darwin"];
    #     # } ({
    #     #   system,
    #     #   pkgs,
    #     # }:
    #     #   import ./checks.nix {inherit inputs system pkgs;});
    #   };
    # };

    nixosConfigurations = {} // (import ./hosts/langhus.nix {inherit inputs;});
    darwinConfigurations = {} // (import ./hosts/smithja.nix {inherit inputs;});

    tests =
      inputs.for-all-systems.forAllSystems {
        nixpkgs = inputs.nixpkgs;
        systems = ["x86_64-linux"];
      } ({
        system,
        pkgs,
      }:
        import ./tests.nix {inherit inputs system pkgs;});

    checks = {
      "x86_64-linux" = {};
    };

    # checks = forAllSystems ({
    #   system,
    #   pkgs,
    # }:
    #   import ./checks.nix {inherit inputs system pkgs;});

    devShells = forAllSystems ({
      system,
      pkgs,
    }:
      import ./devshells.nix {inherit self system pkgs;});
  };
}
