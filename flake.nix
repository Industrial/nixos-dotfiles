{
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Nix Darwin
    nix-darwin.url = "github:lnl7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # NixTest
    nixtest.url = "github:jetpack-io/nixtest";

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

  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }: let
    flake-checks = import ./checks;
    systemConfig = import ./lib/systemConfig.nix;
    langhusSettings = import ./host/langhus/settings.nix;
    smithjaSettings = import ./host/smithja/settings.nix;

    files = [
      ./flake.nix
    ];
  in {
    nixosConfigurations.${langhusSettings.hostname} = (systemConfig inputs ./host/langhus/system ./host/langhus/settings.nix).systemConfiguration;
    darwinConfigurations.${smithjaSettings.hostname} = (systemConfig inputs ./host/langhus/system ./host/langhus/settings.nix).systemConfiguration;

    checks = {
      x86_64-linux = {
        shfmt-check = import ./checks/shfmt.nix {
          inherit nixpkgs;
          path = ./bin;
        };
        shellcheck-check = import ./checks/shellcheck.nix {
          inherit nixpkgs;
          path = ./bin;
        };
        alejandra-check = import ./checks/alejandra.nix {
          inherit nixpkgs;
          path = ./.;
          excludes = [
            ./host/langhus/system/hardware-configuration.nix
          ];
        };
      };
    };
    githubActions = inputs.nix-github-actions.lib.mkGithubMatrix {
      inherit (self) checks;
    };

    # tests = inputs.nixtest.run ./.;
  };
}
