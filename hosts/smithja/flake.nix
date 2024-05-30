{
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-23.11-darwin";
    # Nix Darwin
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    # Nix VSCode Extensions
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    # # MicroVM
    # microvm.url = "github:astro/microvm.nix";
    # microvm.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs @ {
    self,
    nixpkgs,
    darwin,
    # microvm,
    ...
  }: let 
    inherit (nixpkgs.lib) nixosSystem;
    inherit (darwin.lib) darwinSystem;
    system = "aarch64-darwin";
    pkgs = nixpkgs.legacyPackages.${system};
    linuxSystem = builtins.replaceStrings [ "darwin" ] [ "linux" ] system;
    settings = {
      hostname = "smithja";
      stateVersion = "23.11";
      system = system;
      hostPlatform = {
        config = "aarch64-apple-darwin";
        system = system;
      };
      userdir = "/Users/twieland";
      useremail = "twieland@suitsupply.com";
      userfullname = "Tom Wieland";
      username = "twieland";
    };
  in {
    darwinConfigurations = {
      smithja = darwinSystem {
        inherit system;
        specialArgs = {
          inherit inputs settings;
        };
        modules = [
          ./system.nix
          # TODO: Not supported yet on Darwin.
          # microvm.nixosModules.host
          {
            nix = {
              distributedBuilds = true;
              linux-builder = {
                enable = true;
                ephemeral = true;
                maxJobs = 4;
              };
              settings = {
                trusted-users = [ "@admin" ];
              };
            };
          }
        ];
      };
    };
    nixosConfigurations = {
      darwinVM = nixosSystem {
        system = linuxSystem;
        specialArgs = {
          inherit inputs settings;
        };
        modules = [
          ../../features/nix
          ../../features/nix/shell
          ../../features/nixos/users
          ../../features/virtual-machine/base
          ../../features/virtual-machine/ssh
          {
            virtualisation.vmVariant.virtualisation.graphics = false;
            virtualisation.vmVariant.virtualisation.host.pkgs = pkgs;
          }
        ];
      };
      # my-microvm = nixosSystem {
      #   system = linuxSystem;
      #   specialArgs = {
      #     inherit inputs settings;
      #   };
      #   modules = [
      #     microvm.nixosModules.microvm
      #     #../../features/nix
      #     #../../features/nix/shell
      #     #../../features/nixos/users
      #     ../../features/virtual-machine/base
      #     ../../features/virtual-machine/microvm
      #     #../../features/virtual-machine/ssh
      #     {
      #       virtualisation.vmVariant.virtualisation.graphics = false;
      #       virtualisation.vmVariant.virtualisation.host.pkgs = pkgs;
      #     }
      #   ];
      # };
    };
    packages.aarch64-darwin.darwinVM = self.nixosConfigurations.darwinVM.config.system.build.vm;
    # packages.aarch64-darwin.darwinMicroVM = self.nixosConfigurations.my-microvm.config.microvm.declaredRunner;
  };
}
