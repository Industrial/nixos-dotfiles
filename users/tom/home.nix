{ pkgs, inputs, nixpkgs, config, lib, ... }:

{
  #programs.home-manager.enable = true;
  #home.username = "tom";
  #home.homeDirectory = "/home/tom";
  #home.stateVersion = "21.05";

  imports = [
    ./features/git
    ./features/neovim
    ./features/taskwarrior
    ./features/tmux
    ./features/zsh
  ];

  home.packages = [
    pkgs.bitwarden
    pkgs.bookworm
    pkgs.chromium
    pkgs.direnv
    pkgs.discord
    pkgs.docker-compose
    pkgs.element-desktop
    pkgs.exa
    pkgs.fd
    pkgs.filezilla
    pkgs.firefox
    pkgs.fzf
    pkgs.gcc
    pkgs.gitkraken
    pkgs.gnomeExtensions.material-shell
    pkgs.htop
    pkgs.lutris
    pkgs.meld
    pkgs.nethogs
    pkgs.ripgrep
    pkgs.slack
    pkgs.spotify
    pkgs.starship
    pkgs.steam
    pkgs.transmission-gtk
    pkgs.vit
    pkgs.vlc
    pkgs.xclip
    pkgs.xsel
    pkgs.zeal
    pkgs.yubikey-manager-qt
    pkgs.yubikey-personalization-gui

    # Tor
    pkgs.tor-browser-bundle-bin

    # Python
    pkgs.stdenv.cc.cc.lib
    pkgs.python3
    pkgs.virtualenv
    pkgs.poetry

    # Neovim
    pkgs.luajitPackages.luacheck
    pkgs.nodePackages.bash-language-server
    pkgs.nodePackages.dockerfile-language-server-nodejs
    pkgs.nodePackages.stylelint
    pkgs.nodePackages.typescript-language-server
    pkgs.nodePackages.vim-language-server
    pkgs.nodePackages.vscode-langservers-extracted
    pkgs.nodePackages.yaml-language-server
    pkgs.pyright
    pkgs.python-language-server
    pkgs.sumneko-lua-language-server

    # World of Warcraft
    pkgs.alsa-lib
    pkgs.alsa-plugins
    pkgs.giflib
    pkgs.gnutls
    pkgs.gtk3
    pkgs.libgcrypt
    pkgs.libgpg-error
    pkgs.libjpeg
    pkgs.libnghttp2
    pkgs.libpng
    pkgs.libpulseaudio
    pkgs.libva
    pkgs.libxslt
    pkgs.mpg123
    pkgs.ncurses
    pkgs.ocl-icd
    pkgs.openal
    pkgs.sqlite
    pkgs.v4l-utils
    pkgs.xorg.libXcomposite
  ];
}
