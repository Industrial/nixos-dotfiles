{c9config, pkgs, ...}: {
  # Enable system fish.
  programs.fish.enable = true;
  # TODO: c9config.username
  users.users."${c9config.username}".shell = pkgs.fish;
}
