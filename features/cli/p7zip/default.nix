# Archive utility.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    p7zip
  ];
}
