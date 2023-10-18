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

  home.sessionVariables.XDG_CACHE_HOME = "$HOME/.cache";
  home.sessionVariables.XDG_CONFIG_HOME = "$HOME/.config";
  home.sessionVariables.XDG_DATA_HOME = "$HOME/.local/share";
  home.sessionVariables.XDG_STATE_HOME = "$HOME/.local/state";
}
