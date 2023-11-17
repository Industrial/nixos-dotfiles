{pkgs, ...}: {
  # Enable system fish.
  programs.fish.enable = true;
  # TODO: c9config.username
  users.users.tom.shell = pkgs.fish;
}
