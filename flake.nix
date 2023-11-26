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

    # generate iso/qcow2/docker/... image from nixos configuration
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    # Stylix
    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: let
    system = "x86_64-linux";

    # Will be passed into modules.
    args = {
      nixpkgsConfig = {
        allowUnfree = true;
        allowBroken = false;
      };
      c9config = {
        username = "tom";
        userfullname = "Tom Wieland";
        useremail = "tom.wieland@gmail.com";
        userdir = "/home/tom";
      };
    };
  in {
    nixosConfigurations = {
      langhus = inputs.nixpkgs.lib.nixosSystem {
        pkgs = import inputs.nixpkgs {
          inherit system;
          config = args.nixpkgsConfig;
        };

        specialArgs = {
          inherit inputs;
          c9config =
            args.c9config
            // {
              hostname = "langhus";
            };
        };

        modules = [
          ./host/langhus/system
        ];
      };

      # drakkar = inputs.nixpkgs.lib.nixosSystem {
      #   pkgs = import inputs.nixpkgs {
      #     inherit system;
      #     config = args.nixpkgsConfig;
      #   };

      #   specialArgs = {
      #     inherit inputs;
      #     c9config =
      #       args.c9config
      #       // {
      #         hostname = "drakkar";
      #       };
      #   };

      #   modules = [
      #     ./host/drakkar/system
      #   ];
      # };
    };

    darwinConfigurations = {
      smithja = inputs.nix-darwin.lib.darwinSystem {
        pkgs = import inputs.nixpkgs {
          system = "aarch64-darwin";
          config = args.nixpkgsConfig;
        };

        specialArgs = {
          inherit inputs;
          c9config =
            args.c9config
            // {
              hostname = "smithja";
              username = "twieland";
              userfullname = "Tom Wieland";
              useremail = "twieland@suitsupply.com";
              userdir = "/Users/twieland";
            };
        };

        modules = [
          ./host/smithja/system
        ];
      };
    };

    homeConfigurations = {
      "${args.c9config.username}@langhus" = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = import inputs.nixpkgs {
          inherit system;
          config = args.nixpkgsConfig;
        };

        extraSpecialArgs = {
          inherit inputs;
          c9config =
            args.c9config
            // {
              hostname = "langhus";
            };
        };

        modules = [
          ./host/langhus/home-manager
        ];
      };

      # "${args.c9config.username}@drakkar" = inputs.home-manager.lib.homeManagerConfiguration {
      #   pkgs = import inputs.nixpkgs {
      #     inherit system;
      #     config = args.nixpkgsConfig;
      #   };

      #   extraSpecialArgs = {
      #     inherit inputs;
      #     c9config =
      #       args.c9config
      #       // {
      #         hostname = "drakkar";
      #       };
      #   };

      #   modules = [
      #     ./host/drakkar/home-manager
      #   ];
      # };

      "twieland@smithja" = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = import inputs.nixpkgs {
          system = "aarch64-darwin";
          config = args.nixpkgsConfig;
        };

        extraSpecialArgs = {
          inherit inputs;
          c9config =
            args.c9config
            // {
              hostname = "smithja";
              username = "twieland";
              userfullname = "Tom Wieland";
              useremail = "twieland@suitsupply.com";
              userdir = "/Users/twieland";
            };
        };

        modules = [
          ./host/smithja/home-manager
        ];
      };
    };
  };
}
