{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    veracrypt
  ];
}
