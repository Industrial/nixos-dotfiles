# Gitkraken is a git GUI.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    gitkraken
  ];
}
