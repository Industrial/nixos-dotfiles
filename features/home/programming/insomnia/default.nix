# Insomnia is a HTTP test tool.
{
  c9config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    insomnia
  ];
}
