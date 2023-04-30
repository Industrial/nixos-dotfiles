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
          inputs.stylix.homeManagerModules.stylix
          #./features/home/gnome
          #./features/home/zsh
          ./features/home/base16-shell
          ./features/home/fish
          ./features/home/git
          ./features/home/lutris
          ./features/home/matrix
          ./features/home/mpv
          ./features/home/neovim
          ./features/home/stylix
          ./features/home/taskwarrior
          ./features/home/tmux
          ./features/home/vscode
          ./features/home/xfce
          ({...}: {
            home = {
              username = "tom";
              homeDirectory = "/home/tom";
              stateVersion = "20.09";

              sessionVariables = {
                EDITOR = "nvim";
                GIT_EDITOR = "nvim";
                VISUAL = "nvim";
                PAGER = "nvim";
                DIFFPROG = "nvim -d";
                MANPAGER = "nvim +Man!";
                MANWIDTH = 999;
              };

              packages = with pkgs; [
                usbutils
                android-tools
                appimage-run
                bitwarden
                bookworm
                chromium
                direnv
                discord
                docker-compose
                exa
                fd
                filezilla
                firefox
                fzf
                gcc
                gitkraken
                gnomeExtensions.material-shell
                htop
                #libreoffice
                meld
                nethogs
                ripgrep
                slack
                spotify
                starship
                steam
                transmission-gtk
                vit
                vlc
                xclip
                xsel
                yubikey-personalization-gui
                zeal

                # Tor
                tor-browser-bundle-bin

                # Python
                stdenv.cc.cc.lib
                python3
                virtualenv
                poetry

                # Java
                jre8
              ];
            };
          })
        ];
      };
    };
  };
}
