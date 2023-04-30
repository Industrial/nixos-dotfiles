{
  description = "System Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    stylix.url = "github:danth/stylix";
  };

  outputs = inputs: let
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
      drakkar = inputs.nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          #./features/stylix
          #inputs.stylix.nixosModules.stylix
          ./features/boot
          ./features/console
          ./features/disks
          ./features/docker
          ./features/fonts
          ./features/graphics
          ./features/i18n
          ./features/lutris
          ./features/networking
          ./features/nix
          ./features/printing
          ./features/shell
          ./features/sound
          ./features/time
          ./features/users
          ./features/window-manager
          ./features/xfce
          ({...}: {
            imports = [
              ./hardware-configuration.nix
            ];

            # Packages
            environment.systemPackages = with pkgs; [
              # Git (needed for home-manager / flakes)
              git

              # Node.js + Global Packages
              nodejs-19_x
              # overlay
              #promptr
            ];
          })
        ];
      };
    };

    homeConfigurations = {
      "tom@drakkar" = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = pkgs;
        modules = [
          ./users/tom/home
        ];
      };
    };
  };
}
