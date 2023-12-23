{
  pkgs,
  c9config,
  ...
}: {
  home.username = c9config.username;
  home.homeDirectory = c9config.userdir;
  home.stateVersion = c9config.stateVersion;

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
