# Meld is a diff viewer.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    meld
  ];
}
