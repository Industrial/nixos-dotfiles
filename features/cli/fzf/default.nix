# fzf is a fuzzy searcher, use it with CTRL-R in Fish.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    fzf
  ];
}
