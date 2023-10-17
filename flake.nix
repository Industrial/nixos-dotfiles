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
          #./features/system/haskell.nix
          #./features/system/hyprland
          ./features/system/bluetooth
          ./features/system/boot
          ./features/system/chromium
          ./features/system/console
          ./features/system/disks
          ./features/system/docker
          ./features/system/dwm
          ./features/system/fish
          ./features/system/fonts
          ./features/system/git
          ./features/system/glances
          ./features/system/graphics
          ./features/system/home-manager
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
          })
        ];
      };
    };

    homeConfigurations = {
      "tom@drakkar" = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          #./features/home/gnome
          #./features/home/hyprland
          #./features/home/ruby
          #./features/home/vit
          #./features/home/zsh
          ./features/home/alacritty
          ./features/home/ansifilter
          ./features/home/appimage-run
          ./features/home/base16-schemes
          ./features/home/bat
          ./features/home/direnv
          ./features/home/discord
          ./features/home/docker-compose
          ./features/home/dust
          ./features/home/e2fsprogs
          ./features/home/evince
          ./features/home/eza
          ./features/home/fd
          ./features/home/filezilla
          ./features/home/firefox
          ./features/home/fish
          ./features/home/fzf
          ./features/home/git
          ./features/home/gparted
          ./features/home/htop
          ./features/home/lutris
          ./features/home/meld
          ./features/home/mpv
          ./features/home/neovim
          ./features/home/obs-studio
          ./features/home/obsidian
          ./features/home/ripgrep
          ./features/home/spotify
          ./features/home/sqlite
          ./features/home/stylix
          ./features/home/taskwarrior
          ./features/home/transmission
          ./features/home/unzip
          ./features/home/vlc
          ./features/home/vscode
          ./features/home/world-of-warcraft
          ./features/home/xfce
          ./features/home/yubikey-manager
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
            };
          })
        ];
      };
    };
  };
}
