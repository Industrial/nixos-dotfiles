# Okular is a universal document viewer.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    okular
  ];
}
