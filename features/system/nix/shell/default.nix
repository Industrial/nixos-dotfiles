{
  settings,
  pkgs,
  ...
}: {
  # Enable system fish.
  programs.fish.enable = true;
  users.users."${settings.username}".shell = pkgs.fish;
}
