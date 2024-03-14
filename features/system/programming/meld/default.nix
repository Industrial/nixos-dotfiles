# Meld is a diff viewer.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    meld
  ];
}
