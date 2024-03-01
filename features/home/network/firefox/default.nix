# The web browser.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    firefox
  ];
}
