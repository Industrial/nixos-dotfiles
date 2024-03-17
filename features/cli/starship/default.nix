# Prompt.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    starship
  ];
}
