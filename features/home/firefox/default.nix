# The web browser.
{pkgs, ...}: {
  home.packages = with pkgs; [
    firefox
  ];
}
