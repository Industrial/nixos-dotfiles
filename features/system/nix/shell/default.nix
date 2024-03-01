{
  settings,
  pkgs,
  ...
}: {
  # Enable system fish.
  programs.fish.enable = true;
  # TODO: settings.username
  users.users."${settings.username}".shell = pkgs.fish;
}
