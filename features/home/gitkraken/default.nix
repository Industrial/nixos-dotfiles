# Gitkraken is a git GUI.
{pkgs, ...}: {
  home.packages = with pkgs; [
    gitkraken
  ];
}
