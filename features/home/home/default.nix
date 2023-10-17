# This is the home feature. It should at least be included.
{pkgs, ...}: {
  home.username = "tom";
  home.homeDirectory = "/home/tom";
  home.stateVersion = "20.09";

  home.sessionVariables.EDITOR = "nvim";
  home.sessionVariables.GIT_EDITOR = "nvim";
  #home.sessionVariables.VISUAL = "nvim";
  #home.sessionVariables.PAGER = "nvim";
  home.sessionVariables.DIFFPROG = "nvim -d";
  #home.sessionVariables.MANPAGER = "nvim +Man!";
  #home.sessionVariables.MANWIDTH = 999;
}
