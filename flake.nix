{
  description = "Industrial NixOS dotfiles — unified fleet flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    hyprland.url = "github:hyprwm/hyprland";

    quickshell = {
      url = "github:quickshell-mirror/quickshell/28771c7c74b42e20afca0b1b63980cb46515537c";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.quickshell.follows = "quickshell";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    oomkiller-src = {
      url = "path:./rust/tools/oomkiller";
      flake = false;
    };

    nixos-update-notifier-src = {
      url = "path:./rust/tools/nixos-update-notifier";
      flake = false;
    };

    assay.url = "github:Industrial/assay";

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = ["https://nix-community.cachix.org"];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7BKqP7YhK1i3JvGvscqg5k="
    ];
  };

  outputs = inputs @ {self, ...}: let
    lib = inputs.nixpkgs.lib;
    system = "x86_64-linux";
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    hosts = ["drakkar" "huginn" "mimir" "muninn"];
    mkHost = import ./lib/mk-host.nix {inherit inputs;};
    nixosConfigurations =
      lib.genAttrs hosts mkHost
      // {
        # Installer ISO configuration
        installer = lib.nixosSystem {
          inherit system;
          modules = [./installer/configuration.nix];
        };
      };
    deployLib = inputs.deploy-rs.lib.${system};
    mkDeployNode = hostname: {
      inherit hostname;
      profiles.system = {
        # Profile owner must be root for NixOS system activation.
        # SSH as tom; escalate via passwordless sudo (operator-ssh.nix).
        user = "root";
        sshUser = "tom";
        interactiveSudo = false;
        path = deployLib.activate.nixos nixosConfigurations.${hostname};
      };
    };
  in {
    inherit nixosConfigurations;

    # Build with: nix build .#installer-iso
    packages.${system}.installer-iso = nixosConfigurations.installer.config.system.build.isoImage;

    deploy = {
      type = "deploy";
      nodes = lib.genAttrs hosts mkDeployNode;
    };

    checks.${system} = deployLib.deployChecks self.deploy;

    formatter.${system} = pkgs.alejandra;
  };
}
