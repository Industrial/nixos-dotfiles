{pkgs, ...}: {
  # Enable system fish.
  programs.fish.enable = true;
  users.users.tom.shell = pkgs.fish;
}
