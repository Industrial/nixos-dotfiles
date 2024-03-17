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
    vmFirewallSettings = import ./host/vmfirewall/settings.nix;
    vmSettings = import ./host/vm/settings.nix;
  in {
    nixosConfigurations.${langhusSettings.hostname} = (systemConfig inputs langhusSettings).systemConfiguration;
    darwinConfigurations.${smithjaSettings.hostname} = (systemConfig inputs smithjaSettings).systemConfiguration;
    nixosConfigurations.${vmSettings.hostname} = (systemConfig inputs vmSettings).systemConfiguration;
    nixosConfigurations.${vmFirewallSettings.hostname} = (systemConfig inputs vmFirewallSettings).systemConfiguration;
    tests = inputs.nixtest.run ./.;
  };
}
