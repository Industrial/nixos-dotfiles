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
          ./features/system/bluetooth
          ./features/system/boot
          ./features/system/console
          ./features/system/disks
          ./features/system/docker
          ./features/system/fonts
          ./features/system/graphics
          ./features/system/i18n
          ./features/system/lutris
          ./features/system/networking
          ./features/system/nix
          ./features/system/printing
          ./features/system/shell
          ./features/system/sound
          ./features/system/time
          ./features/system/tor
          ./features/system/users
          ./features/system/window-manager
          ./features/system/xfce
          ({...}: {
            imports = [
              ./hardware-configuration.nix
            ];

            # Packages
            environment.systemPackages = with pkgs; [
              # Git (needed for home-manager / flakes)
              git
              p7zip
              xfce.thunar-archive-plugin
              unrar
              xarchiver

              # Node.js + Global Packages
              #nodejs-19_x
              # overlay
              #promptr
            ];
          })
        ];
      };
    };

    homeConfigurations = {
      "tom@drakkar" = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          #./features/home/gnome
          #./features/home/matrix
          #./features/home/zsh
          ./features/home/alacritty
          ./features/home/bat
          ./features/home/dust
          ./features/home/exa
          ./features/home/fd
          ./features/home/fish
          ./features/home/fzf
          ./features/home/git
          ./features/home/htop
          ./features/home/lutris
          ./features/home/mpv
          ./features/home/neovim
          ./features/home/ripgrep
          ./features/home/ruby
          ./features/home/stylix
          ./features/home/taskwarrior
          ./features/home/unzip
          ./features/home/vit
          ./features/home/vscode
          ./features/home/xfce
          ./features/home/zellij
          inputs.stylix.homeManagerModules.stylix
          ({...}: {
            home = {
              username = "tom";
              homeDirectory = "/home/tom";
              stateVersion = "20.09";

              sessionVariables = {
                EDITOR = "nvim";
                GIT_EDITOR = "nvim";
                #VISUAL = "nvim";
                #PAGER = "nvim";
                DIFFPROG = "nvim -d";
                #MANPAGER = "nvim +Man!";
                #MANWIDTH = 999;
              };

              packages = with pkgs; [
                # NixOS
                direnv

                # Docker
                docker-compose

                # Development
                # Sqlite
                sqlite
                gcc

                # Git
                meld

                # Internet
                filezilla
                firefox
                transmission-gtk

                # Media
                spotify
                vlc
                obs-studio
                obsidian

                # Social
                discord

                # Games
                path-of-building

                # Window Manager
                slock

                # Other
                appimage-run
              ];
            };
          })
        ];
      };
    };
  };
}
