# Insomnia is a HTTP test tool.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    insomnia
  ];
}
