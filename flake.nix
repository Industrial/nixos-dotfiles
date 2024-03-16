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
    vmSettings = import ./host/vm/settings.nix;

    # createConfigurations = directoryPath: let
    #   hostDirectoryNames = builtins.attrNames (builtins.readDir directoryPath);
    # in
    #   builtins.listToAttrs (map (hostDirectoryName: let
    #       settings = import ./${directoryPath}/${hostDirectoryName}/settings.nix;
    #       config = systemConfig inputs settings;
    #     in {
    #       name = "nixosConfigurations.${settings.hostname}";
    #       value = config.systemConfiguration;
    #     })
    #     hostDirectoryNames);

    langhusConfiguration = systemConfig inputs langhusSettings;
    smithjaConfiguration = systemConfig inputs smithjaSettings;
    vmConfiguration = systemConfig inputs vmSettings;
  in {
    nixosConfigurations.${langhusSettings.hostname} = langhusConfiguration.systemConfiguration;
    homeConfigurations."${langhusSettings.username}@${langhusSettings.hostname}" = langhusConfiguration.homeConfiguration;

    darwinConfigurations.${smithjaSettings.hostname} = smithjaConfiguration.systemConfiguration;
    homeConfigurations."${smithjaSettings.username}@${smithjaSettings.hostname}" = smithjaConfiguration.homeConfiguration;

    nixosConfigurations.${vmSettings.hostname} = vmConfiguration.systemConfiguration;
    # createConfigurations ./host;
  };
}
