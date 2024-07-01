# Ansifilter can filter text.
# Examples:
# * Remove control characters:
#   $ cat dirty.txt | ansifilter --text > clean.txt
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    ansifilter
  ];
}
