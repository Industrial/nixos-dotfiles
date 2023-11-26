{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # CLI
    ../../../features/home/cli/ansifilter
    ../../../features/home/cli/appimage-run
    ../../../features/home/cli/base16-schemes
    ../../../features/home/cli/bat
    ../../../features/home/cli/btop
    ../../../features/home/cli/direnv
    ../../../features/home/cli/dust
    ../../../features/home/cli/e2fsprogs
    ../../../features/home/cli/eza
    ../../../features/home/cli/fd
    ../../../features/home/cli/fish
    ../../../features/home/cli/fzf
    ../../../features/home/cli/htop
    ../../../features/home/cli/neovim
    ../../../features/home/cli/ranger
    ../../../features/home/cli/ripgrep
    # ../../../features/home/cli/taskwarrior
    ../../../features/home/cli/unzip
    # ../../../features/home/cli/vit
    ../../../features/home/cli/zellij
    # ../../../features/home/cli/zsh

    # Communication
    ../../../features/home/communication/discord

    # Crypto
    ../../../features/home/crypto/monero

    # Games
    ../../../features/home/games/lutris
    ../../../features/home/games/world-of-warcraft

    # Home
    ../../../features/home/home

    # Lab

    # Media
    ../../../features/home/media/eog
    ../../../features/home/media/mpv
    ../../../features/home/media/obs-studio
    ../../../features/home/media/spotify
    ../../../features/home/media/vlc

    # Network
    ../../../features/home/network/filezilla
    ../../../features/home/network/firefox
    ../../../features/home/network/transmission

    # Programming
    ../../../features/home/programming/docker-compose
    ../../../features/home/programming/git
    ../../../features/home/programming/gitkraken
    ../../../features/home/programming/meld
    # ../../../features/home/programming/ruby
    ../../../features/home/programming/sqlite

    # Window Manager
    ../../../features/home/window-manager/alacritty
    ../../../features/home/window-manager/dwm
    ../../../features/home/window-manager/evince
    ../../../features/home/window-manager/feh
    ../../../features/home/window-manager/gimp
    # ../../../features/home/window-manager/gnome
    ../../../features/home/window-manager/gparted
    ../../../features/home/window-manager/gscreenshot
    ../../../features/home/window-manager/hyprland
    ../../../features/home/window-manager/inkscape
    ../../../features/home/window-manager/obsidian
    ../../../features/home/window-manager/slock
    ../../../features/home/window-manager/stylix
    ../../../features/home/window-manager/vscode
    ../../../features/home/window-manager/xfce
    ../../../features/home/window-manager/yubikey-manager
    inputs.stylix.homeManagerModules.stylix
  ];
}
