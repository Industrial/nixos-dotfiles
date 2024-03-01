# Btop is a htop replacement
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    btop
  ];
}
