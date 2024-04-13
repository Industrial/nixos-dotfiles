{
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Nix Darwin
    nix-darwin.url = "github:lnl7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Flake Parts
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs.follows = "nixpkgs";
    # mission-control.url = "github:Platonic-Systems/mission-control";
    # mission-control.inputs.nixpkgs.follows = "nixpkgs";
    # flake-root.url = "github:srid/flake-root";
    # flake-root.inputs.nixpkgs.follows = "nixpkgs";

    # # Flake Utils
    # flake-utils.url = "github:numtide/flake-utils";

    # NixTest
    nixtest.url = "github:jetpack-io/nixtest";

    # Nix PreCommit Hooks
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

    # Nix Github Actions
    nix-github-actions.url = "github:nix-community/nix-github-actions";
    nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";

    # MicroVM
    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    # Nix VSCode Extensions
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";

    # Stylix
    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    # Cryptpad
    cryptpad.url = "github:michaelshmitty/cryptpad-flake";
    cryptpad.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        # "aarch64-darwin"
      ];

      imports = [
        ./hosts
        # inputs.mission-control.flakeModule
        # inputs.flake-root.flakeModule
      ];

      perSystem = {system, ...}: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };
      };

      # perSystem = {
      #   config,
      #   inputs',
      #   lib,
      #   pkgs,
      #   self',
      #   self,
      #   system,
      #   ...
      # }: {
      #   _module.args.pkgs = import self.inputs.nixpkgs {
      #     inherit system;
      #     overlays = [self.overlays.default];
      #     config = {
      #       allowUnfree = true;
      #       allowBroken = false;
      #     };
      #   };
      # };
    };

  # outputs = inputs @ {
  #   self,
  #   nixpkgs,
  #   flake-parts,
  #   ...
  # }: let
  #   flake-checks = import ./checks;
  #   systemConfig = import ./lib/systemConfig.nix;
  #   langhusSettings = import ./hosts/langhus/settings.nix;
  #   smithjaSettings = import ./hosts/smithja/settings.nix;

  #   files = [
  #     ./flake.nix
  #   ];
  # in
  # flake-parts.lib.mkFlake {inherit inputs;} {
  #   systems = [
  #     "x86_64-linux"
  #     # "aarch64-darwin"
  #   ];

  #   imports = [
  #     ./hosts
  #     # inputs.mission-control.flakeModule
  #     # inputs.flake-root.flakeModule
  #   ];

  #   # flake = {
  #   #   darwinConfigurations = {
  #   #     ${smithjaSettings.hostname} = (systemConfig inputs pkgs ./hosts/langhus/system ./hosts/langhus/settings.nix).systemConfiguration;
  #   #   };
  #   # };

  #   # devShells.default = pkgs.mkShell {
  #   #   nativeBuildInputs = with pkgs; [
  #   #     pkgs.nixpkgs-fmt
  #   #     pkgs.shellcheck
  #   #     pkgs.alejandra
  #   #   ];
  #   #   inputsFrom = [
  #   #     config.mission-control.devShell
  #   #     config.flake-root.devShell
  #   #   ];
  #   # };

  #   # mission-control = {
  #   #   wrapperName = "run";
  #   #   scripts = {
  #   #     build = {
  #   #       description = "Nix file formatter";
  #   #       exec = ''
  #   #         alejandra -c -e $FLAKE_ROOT/host/langhus/system/hardware-configuration.nix .
  #   #       '';
  #   #       category = "Lint";
  #   #     };
  #   #   };
  #   # };

  #   # checks = {
  #   #   pre-commit-check = inputs.pre-commit-hooks.lib.x86_64-linux.run {
  #   #     src = ./.;
  #   #     hooks = {
  #   #       nixpkgs-fmt.enable = true;
  #   #     };
  #   #   };
  #   #   x86_64-linux = {
  #   #     shfmt-bin = with import nixpkgs {system = "x86_64-linux";};
  #   #       pkgs.runCommand "shfmt-bin" {
  #   #         nativeBuildInputs = [shfmt];
  #   #       } "shfmt -d -s -i 2 -ci ${./bin}";
  #   #     shellcheck-bin = with import nixpkgs {system = "x86_64-linux";};
  #   #       pkgs.runCommand "shellcheck-bin" {
  #   #         nativeBuildInputs = [shellcheck];
  #   #       } "shellcheck -x ${./bin}/*";
  #   #     alejandra-nix = with import nixpkgs {system = "x86_64-linux";};
  #   #       pkgs.runCommand "alejandra-nix" {
  #   #         nativeBuildInputs = [alejandra];
  #   #       } "alejandra -c -e ./hosts/langhus/system/hardware-configuration.nix ${./.}";
  #   #   };
  #   # };

  #   # githubActions = inputs.nix-github-actions.lib.mkGithubMatrix {
  #   #   inherit (self) checks;
  #   # };

  #   # tests = inputs.nixtest.run ./.;
  # };
}
