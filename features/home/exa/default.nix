# exa is a ls replacement.
{pkgs, ...}: {
  home.packages = with pkgs; [
    exa
  ];
}
