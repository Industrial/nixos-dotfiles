# Okular is a universal document viewer.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    okular
  ];
}
