# eza is a ls replacement.
{pkgs, ...}: {
  home.packages = with pkgs; [
    eza
  ];
}
