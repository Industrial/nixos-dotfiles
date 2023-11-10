# CryptPad is a collaborative office suite that is end-to-end encrypted and
# open-source.
{pkgs, ...}: {
  home.packages = with pkgs; [
    gscreenshot
  ];
}
