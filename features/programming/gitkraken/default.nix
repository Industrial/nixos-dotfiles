# Gitkraken is a git GUI.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    gitkraken
  ];
}
