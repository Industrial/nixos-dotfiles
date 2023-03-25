{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./features/git
    ./features/gnome
    ./features/mpv
    ./features/neovim
    ./features/taskwarrior
    ./features/tmux
    ./features/vscode
    ./features/zsh
  ];

  home = {
    sessionVariables = {
      EDITOR = "nvim";
      GIT_EDITOR = "nvim";
      VISUAL = "nvim";
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
      libreoffice
      lutris
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

      # Matrix
      cinny-desktop

      # Tor
      tor-browser-bundle-bin

      # Python
      stdenv.cc.cc.lib
      python3
      virtualenv
      poetry

      # Java
      jre8

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
  };
}
