# eza is a ls replacement.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    eza
  ];
}
