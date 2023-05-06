{pkgs, ...}: {
  home.packages = with pkgs; [
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
