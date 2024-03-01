# Ansifilter can filter text.
# Examples:
# * Remove control characters:
#   $ cat dirty.txt | ansifilter --text > clean.txt
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    ansifilter
  ];
}
