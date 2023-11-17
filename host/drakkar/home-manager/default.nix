{pkgs, inputs, ...}: {
  imports = [
    ../../../features/home/home

    # CLI
    ../../../features/home/ansifilter
    ../../../features/home/appimage-run
    ../../../features/home/base16-schemes
    ../../../features/home/bat
    ../../../features/home/btop
    ../../../features/home/direnv
    ../../../features/home/dust
    ../../../features/home/e2fsprogs
    ../../../features/home/eza
    ../../../features/home/fd
    ../../../features/home/fish
    ../../../features/home/fzf
    ../../../features/home/htop
    ../../../features/home/neovim
    ../../../features/home/ranger
    ../../../features/home/ripgrep
    ../../../features/home/unzip
    ../../../features/home/zellij

    # Window Manager / Desktop
    ../../../features/home/dwm
    ../../../features/home/xfce

    # Network
    ../../../features/home/filezilla
    ../../../features/home/firefox
    ../../../features/home/transmission

    # Programming
    ../../../features/home/docker-compose
    ../../../features/home/git
    ../../../features/home/gitkraken
    ../../../features/home/sqlite
    ../../../features/home/vscode

    # Communication
    ../../../features/home/discord

    # Media
    ../../../features/home/mpv
    ../../../features/home/obs-studio
    ../../../features/home/spotify
    ../../../features/home/vlc

    # GUI / Window Manager
    ../../../features/home/alacritty
    ../../../features/home/evince
    ../../../features/home/feh
    ../../../features/home/gimp
    ../../../features/home/gparted
    ../../../features/home/gscreenshot
    ../../../features/home/inkscape
    ../../../features/home/meld
    ../../../features/home/obsidian
    ../../../features/home/stylix
    ../../../features/home/yubikey-manager
    inputs.stylix.homeManagerModules.stylix

    # Games
    ../../../features/home/games/lutris
    ../../../features/home/games/world-of-warcraft

    # Crypto
    ../../../features/home/monero
  ];
}