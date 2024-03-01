{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    homebank
  ];
}
