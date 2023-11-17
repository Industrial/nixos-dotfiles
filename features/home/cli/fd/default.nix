# FD is a file finder.
{pkgs, ...}: {
  home.packages = with pkgs; [
    fd
  ];
}
