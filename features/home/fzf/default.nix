# fzf is a fuzzy searcher, use it with CTRL-R in Fish.
{pkgs, ...}: {
  home.packages = with pkgs; [
    fzf
  ];
}
