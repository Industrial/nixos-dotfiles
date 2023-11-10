{
  description = "System Flake";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # generate iso/qcow2/docker/... image from nixos configuration
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    # Stylix
    stylix.url = "github:danth/stylix";
  };

  # nixConfig = {
  #   experimental-features = ["nix-command flakes"];
  #   extra-substituters = [
  #     "https://nix-community.cachix.org"
  #   ]
  # };

  outputs = inputs: let
    # Will be passed into modules.
    args = {
      c9config = {
        username = "tom";
        userfullname = "Tom Wieland";
        useremail = "tom.wieland@gmail.com";
      };
    };

    # x64_system = "x86_64-linux";
    # x64_darwin = "x86_64-darwin";
    # allSystems = [
    #   x64_system
    #   # x64_darwin
    # ];

    system = "x86_64-linux";
    pkgs = import inputs.nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        allowBroken = false;
      };
    };
  in {
    nixosConfigurations = {
      langhus = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        inherit pkgs;

        specialArgs = {
          inherit inputs;
          c9config = args.c9config // {
            hostname = "langhus";
          };
        };

        modules = [
          ./host/langhus/system
        ];
      };
    };

    homeConfigurations = {
      "${args.c9config.username}@langhus" = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        extraSpecialArgs = {
          inherit inputs;
          c9config = args.c9config // {
            hostname = "langhus";
          };
        };

        modules = [
          ./host/langhus/home-manager
        ];
      };
    };
  };
}
