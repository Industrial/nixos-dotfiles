# The web browser.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    firefox
  ];
}
