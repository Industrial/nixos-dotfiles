{
  settings,
  pkgs,
  ...
}: {
  fonts.packages = with pkgs; [
    nerdfonts
  ];
}
