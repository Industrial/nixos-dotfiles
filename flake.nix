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
          ./features/system/fish
          ./features/system/fonts
          ./features/system/git
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
          ./features/system/syncthing
          ./features/system/system
          ./features/system/time
          ./features/system/tor
          ./features/system/unrar
          ./features/system/users
          ./features/system/window-manager
          ./features/system/xfce
        ];
      };
    };

    homeConfigurations = {
      "tom@drakkar" = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          ./features/home/home

          # CLI
          ./features/home/ansifilter
          ./features/home/appimage-run
          ./features/home/base16-schemes
          ./features/home/bat
          ./features/home/btop
          ./features/home/direnv
          ./features/home/dust
          ./features/home/e2fsprogs
          ./features/home/eza
          ./features/home/fd
          ./features/home/fish
          ./features/home/fzf
          ./features/home/htop
          ./features/home/neovim
          ./features/home/ranger
          ./features/home/ripgrep
          ./features/home/taskwarrior
          ./features/home/unzip
          ./features/home/zellij

          # Window Manager / Desktop
          ./features/home/dwm
          ./features/home/xfce

          # Network
          ./features/home/filezilla
          ./features/home/firefox
          ./features/home/transmission

          # Programming
          ./features/home/docker-compose
          ./features/home/git
          ./features/home/gitkraken
          ./features/home/sqlite
          ./features/home/vscode

          # Communication
          ./features/home/discord

          # Media
          ./features/home/mpv
          ./features/home/obs-studio
          ./features/home/spotify
          ./features/home/vlc

          # GUI / Window Manager
          ./features/home/alacritty
          ./features/home/evince
          ./features/home/feh
          ./features/home/gimp
          ./features/home/gparted
          ./features/home/gscreenshot
          ./features/home/inkscape
          ./features/home/meld
          ./features/home/obsidian
          ./features/home/stylix
          ./features/home/yubikey-manager
          inputs.stylix.homeManagerModules.stylix

          # Games
          ./features/home/lutris
          ./features/home/world-of-warcraft

          # Crypto
          ./features/home/monero

          # Unused
          #./features/home/gnome
          #./features/home/hyprland
          #./features/home/ruby
          #./features/home/vit
          #./features/home/zsh
        ];
      };
    };
  };
}
