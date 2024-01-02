{
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Flake Utils
    flake-utils.url = "github:numtide/flake-utils";

    # Nix Darwin
    nix-darwin.url = "github:lnl7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # # generate iso/qcow2/docker/... image from nixos configuration
    # nixos-generators.url = "github:nix-community/nixos-generators";
    # nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    # Nix VSCode Extensions
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";

    # Stylix
    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    ...
  }: let
    systemConfig = import ./lib/systemConfig.nix;

    settings = {
      hostname = "langhus";
      stateVersion = "24.05";
      system = "x86_64-linux";
      userdir = "/home/tom";
      useremail = "tom.wieland@gmail.com";
      userfullname = "Tom Wieland";
      username = "tom";
    };

    darwinSettings = {
      hostname = "smithja";
      stateVersion = "24.05";
      system = "aarch64-darwin";
      userdir = "/Users/twieland";
      useremail = "twieland@suitsupply.com";
      userfullname = "Tom Wieland";
      username = "twieland";
    };

    nixosConfiguration = systemConfig inputs settings;
    darwinConfiguration = systemConfig inputs darwinSettings;
  in {
    nixosConfigurations.${settings.hostname} = nixosConfiguration.systemConfiguration;
    homeConfigurations."${settings.username}@${settings.hostname}" = nixosConfiguration.homeConfiguration;

    darwinConfigurations.${darwinSettings.hostname} = darwinConfiguration.systemConfiguration;
    homeConfigurations."${darwinSettings.username}@${darwinSettings.hostname}" = darwinConfiguration.homeConfiguration;
  };
}
