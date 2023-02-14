{
  description = "System Flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-master.url = "nixpkgs/master";
    home-manager = {
      url = "github:nix-community/home-manager/release-20.09";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };

  outputs = inputs@{
    self
    , nixpkgs
    , nixpkgs-master
    , home-manager,
    ...
  }: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };

    master = import nixpkgs-master {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };

    lib = nixpkgs.lib;

    home = [
      home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.tom = lib.mkMerge [
          ./users/tom/home.nix
        ];
      }
    ];
  in {
    packages."${system}" =
      mapModules ./packages (p: pkgs.callPackage p {});
    ];

    nixosConfigurations = {
      drakkar = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/drakkar.nix
          common
        ] ++ home;
        specialArgs = {
          inherit inputs;
          inherit home-manager;
        };
      };
    };
  };
}
