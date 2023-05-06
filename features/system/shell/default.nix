{pkgs, ...}: {
  programs.fish.enable = true;
  users.users.tom.shell = pkgs.fish;
}
