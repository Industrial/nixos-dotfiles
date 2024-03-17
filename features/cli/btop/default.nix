# Btop is a htop replacement
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    btop
  ];
}
