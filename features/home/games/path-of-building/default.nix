{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    path-of-building
  ];
}
