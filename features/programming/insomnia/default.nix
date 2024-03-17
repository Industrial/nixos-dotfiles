# Insomnia is a HTTP test tool.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    insomnia
  ];
}
