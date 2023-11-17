# Ansifilter can filter text.
# Examples:
# * Remove control characters:
#   $ cat dirty.txt | ansifilter --text > clean.txt
{pkgs, ...}: {
  home.packages = with pkgs; [
    ansifilter
  ];
}
