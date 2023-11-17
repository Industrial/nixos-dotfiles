# I need unzip.
{pkgs, ...}: {
  home.packages = with pkgs; [
    unzip
  ];
}
