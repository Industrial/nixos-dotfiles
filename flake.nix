{
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Nix Darwin
    nix-darwin.url = "github:lnl7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # NixTest
    nixtest.url = "github:jetpack-io/nixtest";

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

  outputs = inputs @ {nixpkgs, ...}: let
    systemConfig = import ./lib/systemConfig.nix;
    langhusSettings = import ./host/langhus/settings.nix;
    smithjaSettings = import ./host/smithja/settings.nix;
  in {
    nixosConfigurations.${langhusSettings.hostname} = (systemConfig inputs ./host/langhus/system ./host/langhus/settings.nix).systemConfiguration;
    darwinConfigurations.${smithjaSettings.hostname} = (systemConfig inputs ./host/langhus/system ./host/langhus/settings.nix).systemConfiguration;
    tests = inputs.nixtest.run ./.;
  };
}
