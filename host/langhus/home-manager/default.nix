{
  settings,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # CLI
    ../../../features/home/cli/fish
    ../../../features/home/cli/neovim
    ../../../features/home/cli/zellij

    # Games
    ../../../features/home/games/lutris
    ../../../features/home/games/path-of-building
    ../../../features/home/games/steam

    # Home
    ../../../features/home/home

    # Media
    ../../../features/home/media/lxqt-pavucontrol-qt
    ../../../features/home/media/lxqt-screengrab
    ../../../features/home/media/okular
    ../../../features/home/media/spotify
    ../../../features/home/media/vlc

    # Monitoring
    ../../../features/home/monitoring/lxqt-qps

    # Network
    ../../../features/home/network/chromium
    ../../../features/home/network/firefox
    ../../../features/home/network/tor-browser

    # Office
    ../../../features/home/office/evince
    ../../../features/home/office/obsidian
    ../../../features/home/office/lxqt-pcmanfm-qt
    ../../../features/home/office/lxqt-archiver

    # Programming
    ../../../features/home/programming/android-tools
    ../../../features/home/programming/docker-compose
    ../../../features/home/programming/git
    ../../../features/home/programming/gitkraken
    # TODO: Fix. There was a security issue: CVE-2024-27297
    # ../../../features/home/programming/nixd
    ../../../features/home/programming/nodejs
    ../../../features/home/programming/sqlite
    ../../../features/home/programming/vscode

    # Security
    ../../../features/home/security/bitwarden
    ../../../features/home/security/veracrypt
    ../../../features/home/security/yubikey-manager

    # Window Manager
    ../../../features/home/window-manager/alacritty
    ../../../features/home/window-manager/dwm
    ../../../features/home/window-manager/slock
    ../../../features/home/window-manager/stylix
    ../../../features/home/window-manager/xmonad
    inputs.stylix.homeManagerModules.stylix
  ];
}
