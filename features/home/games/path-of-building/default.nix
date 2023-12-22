{
  c9config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    path-of-building
  ];
}
