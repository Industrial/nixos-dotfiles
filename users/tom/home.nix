{
  pkgs,
  inputs,
  nixpkgs,
  config,
  lib,
  system,
  ...
}: {
  home = {
    username = "tom";
    homeDirectory = "/home/tom";
    stateVersion = "21.05";
  };

  nixpkgs = {
    config = {
      inherit system;
      allowUnfree = true;
      allowBroken = true;
      experimental-features = ["nix-command" "flakes"];
    };
  };

  programs = {
    home-manager = {
      enable = true;
    };
  };

  imports = [
    ./features/git
    ./features/neovim
    ./features/taskwarrior
    ./features/tmux
    ./features/vscode
    ./features/zsh
  ];

  home.packages = with pkgs; [
    appimage-run
    bitwarden
    bookworm
    chromium
    direnv
    discord
    docker-compose
    element-desktop
    exa
    fd
    filezilla
    firefox
    fzf
    gcc
    gitkraken
    gnomeExtensions.material-shell
    htop
    lutris-unwrapped
    meld
    nethogs
    ripgrep
    slack
    libreoffice

    # TODO: Get this to work..
    spotify

    starship
    steam
    transmission-gtk
    vit
    vlc
    xclip
    xsel
    zeal
    yubikey-manager-qt
    yubikey-personalization-gui

    # Tor
    tor-browser-bundle-bin

    # Python
    stdenv.cc.cc.lib
    python3
    virtualenv
    poetry

    # World of Warcraft
    alsa-lib
    alsa-plugins
    giflib
    gnutls
    gtk3
    libgcrypt
    libgpg-error
    libjpeg
    libnghttp2
    libpng
    libpulseaudio
    libva
    libxslt
    mpg123
    ncurses
    ocl-icd
    openal
    sqlite
    v4l-utils
    xorg.libXcomposite
  ];
}
