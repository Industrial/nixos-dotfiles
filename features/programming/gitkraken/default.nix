# Gitkraken is a git GUI.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    gitkraken
  ];
}
