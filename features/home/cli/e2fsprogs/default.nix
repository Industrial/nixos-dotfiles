# e2fsprogs contains hard disk tools. https://en.wikipedia.org/wiki/E2fsprogs
{pkgs, ...}: {
  home.packages = with pkgs; [
    e2fsprogs
  ];
}
