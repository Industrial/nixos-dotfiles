{
  inputs = {
    # Nixpkgs
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";

    # Nix Darwin
    nix-darwin.url = "github:lnl7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Flake Parts
    flake-parts.url = "github:hercules-ci/flake-parts";

    # # NixTest
    # nixtest.url = "github:jetpack-io/nixtest";

    # # Nix PreCommit Hooks
    # pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

    # Nix Github Actions
    nix-github-actions.url = "github:nix-community/nix-github-actions";
    nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";

    # MicroVM
    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    # NixVim
    nixvim.url = "https://flakehub.com/f/nix-community/nixvim/0.1.*.tar.gz";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    # Nix VSCode Extensions
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";

    # Stylix
    stylix.url = "https://flakehub.com/f/danth/stylix/0.1.*.tar.gz";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    # Cryptpad
    cryptpad.url = "https://flakehub.com/f/michaelshmitty/cryptpad/2.2.0.tar.gz";
    cryptpad.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    flake-parts,
    nixpkgs,
    ...
  }: let 
    darwin-builder = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        "${nixpkgs}/nixos/modules/profiles/macos-builder.nix"
        {
          virtualisation = {
            host.pkgs = nixpkgs.legacyPackages."aarch64-linux";
            darwin-builder.workingDirectory = "/var/lib/darwin-builder";
          };
        }
      ];
    };
  in flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      imports = [
        ./hosts
      ];

      flake = {
        nixosModules.base = {pkgs, ...}: {
          system.stateVersion = "23.11";

          # Configure networking
          networking.useDHCP = false;
          networking.interfaces.eth0.useDHCP = true;

          # Create user "test"
          services.getty.autologinUser = "test";
          users.users.test.isNormalUser = true;

          # Enable passwordless ‘sudo’ for the "test" user
          users.users.test.extraGroups = ["wheel"];
          security.sudo.wheelNeedsPassword = false;
        };

        nixosModules.vm = {...}: {
          virtualisation.vmVariant.virtualisation.graphics = false;
        };

        nixosConfigurations.darwinVM = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            self.nixosModules.base
            self.nixosModules.vm
            {
              virtualisation.vmVariant.virtualisation.host.pkgs = nixpkgs.legacyPackages.aarch64-darwin;
            }
            # (import (nixpkgs.path + "/nixos/modules/profiles/macos-builder.nix"))
          ];
        };
        packages.aarch64-darwin.darwinVM = self.nixosConfigurations.darwinVM.config.system.build.vm;

        nix = {
          linux-builder = {
            enable = true;
            ephemeral = true;
            maxJobs = 4;
          };
          trusted-users = [ "@admin" ];
        };

        # nix.distributedBuilds = true;
        # nix.buildMachines = [{
        #   hostName = "ssh://builder@localhost";
        #   system = "aarch64-linux";
        #   maxJobs = 4;
        #   supportedFeatures = [ "kvm" "benchmark" "big-parallel" ];
        # }];
        # launchd.agents = {
        #   darwin-builder = {
        #     command = "${darwin-builder.config.system.build.macos-builder-installer}/bin/create-builder";
        #     serviceConfig = {
        #       KeepAlive = true;
        #       RunAtLoad = true;
        #       StandardOutPath = "/var/log/darwin-builder.log";
        #       StandardErrorPath = "/var/log/darwin-builder.log";
        #     };
        #   };
        # };
      };

      perSystem = {
        system,
        lib,
        inputs,
        ...
      }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config = lib.mkForce {
            allowUnfree = true;
          };
        };
      };
    };

  # checks = {
  #   pre-commit-check = inputs.pre-commit-hooks.lib.x86_64-linux.run {
  #     src = ./.;
  #     hooks = {
  #       nixpkgs-fmt.enable = true;
  #     };
  #   };
  #   x86_64-linux = {
  #     shfmt-bin = with import nixpkgs {system = "x86_64-linux";};
  #       pkgs.runCommand "shfmt-bin" {
  #         nativeBuildInputs = [shfmt];
  #       } "shfmt -d -s -i 2 -ci ${./bin}";
  #     shellcheck-bin = with import nixpkgs {system = "x86_64-linux";};
  #       pkgs.runCommand "shellcheck-bin" {
  #         nativeBuildInputs = [shellcheck];
  #       } "shellcheck -x ${./bin}/*";
  #     alejandra-nix = with import nixpkgs {system = "x86_64-linux";};
  #       pkgs.runCommand "alejandra-nix" {
  #         nativeBuildInputs = [alejandra];
  #       } "alejandra -c -e ./hosts/langhus/system/hardware-configuration.nix ${./.}";
  #   };
  # };
}
