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
        inherit pkgs;

        modules = [
          ./features/system/bluetooth
          ./features/system/boot
          ./features/system/chromium
          ./features/system/console
          ./features/system/disks
          ./features/system/docker
          ./features/system/fonts
          ./features/system/git
          ./features/system/glances
          ./features/system/graphics
          ./features/system/i18n
          ./features/system/lutris
          ./features/system/networking
          ./features/system/nix
          ./features/system/p7zip
          ./features/system/printing
          ./features/system/shell
          ./features/system/sound
          ./features/system/starship
          ./features/system/time
          ./features/system/tor
          ./features/system/unrar
          ./features/system/users
          ./features/system/window-manager
          ./features/system/xfce
          ({...}: {
            imports = [
              ./hardware-configuration.nix
            ];

            # Packages
            environment.systemPackages = with pkgs; [
              xfce.thunar-archive-plugin
              xarchiver

              # Python
              python3Full
              xorg.xwininfo
              wmctrl

              # Node.js + Global Packages
              #nodejs-19_x
              # overlay
              #promptr

              # Fish
              # TODO: Put in system fish feature. Not installable with home manager.
              fishPlugins.bass
              fishPlugins.fzf
            ];
          })
        ];
      };
    };

    homeConfigurations = {
      "tom@drakkar" = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          ./features/home/alacritty
          ./features/home/appimage-run
          ./features/home/base16-schemes
          ./features/home/bat
          ./features/home/direnv
          ./features/home/discord
          ./features/home/docker-compose
          ./features/home/dust
          ./features/home/eza
          ./features/home/fd
          ./features/home/filezilla
          ./features/home/firefox
          ./features/home/fish
          ./features/home/fzf
          ./features/home/git
          #./features/home/gnome
          ./features/home/htop
          #./features/home/hyprland
          ./features/home/lutris
          ./features/home/meld
          ./features/home/mpv
          # ./features/home/neovim
          ./features/home/obs-studio
          ./features/home/obsidian
          ./features/home/ripgrep
          #./features/home/ruby
          ./features/home/spotify
          ./features/home/sqlite
          ./features/home/stylix
          ./features/home/taskwarrior
          ./features/home/transmission
          ./features/home/unzip
          #./features/home/vit
          ./features/home/vlc
          ./features/home/vscode
          ./features/home/world-of-warcraft
          ./features/home/xfce
          ./features/home/zellij
          #./features/home/zsh
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
                # Games
                path-of-building

                # Window Manager
                slock
              ];
            };
          })
        ];
      };
    };
  };
}
