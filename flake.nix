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
  };

  outputs = inputs @ {self, ...}: let
    lib = inputs.nixpkgs.lib;
    hosts = ["drakkar" "huginn" "mimir"];
    mkHost = import ./lib/mk-host.nix {inherit inputs;};
    nixosConfigurations = lib.genAttrs hosts mkHost;
    deployLib = inputs.deploy-rs.lib.x86_64-linux;
    mkDeployNode = hostname: {
      inherit hostname;
      profiles.system = {
        user = "tom";
        sshUser = "tom";
        # Passwordless sudo for tom on fleet hosts (features/fleet/operator-ssh.nix).
        interactiveSudo = false;
        path = deployLib.activate.nixos nixosConfigurations.${hostname};
      };
    };
  in {
    inherit nixosConfigurations;

    deploy = {
      type = "deploy";
      nodes = lib.genAttrs hosts mkDeployNode;
    };

    checks.x86_64-linux = deployLib.deployChecks self.deploy;

    formatter.x86_64-linux = inputs.nixpkgs.legacyPackages.x86_64-linux.alejandra;
  };
}
