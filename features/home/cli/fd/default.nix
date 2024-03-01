# FD is a file finder.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    fd
  ];
}
