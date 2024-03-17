{
  settings,
  pkgs,
  ...
}: {
  home.username = settings.username;
  home.homeDirectory = settings.userdir;
  home.stateVersion = settings.stateVersion;
}
