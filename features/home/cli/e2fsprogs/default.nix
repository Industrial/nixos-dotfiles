# e2fsprogs contains hard disk tools. https://en.wikipedia.org/wiki/E2fsprogs
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    e2fsprogs
  ];
}
