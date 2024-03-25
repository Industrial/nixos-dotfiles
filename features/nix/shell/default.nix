{
  settings,
  pkgs,
  ...
}: {
  programs.bash.enable = true;
  programs.fish.enable = true;
  environment.shells = with pkgs; [bashInteractive fish];
  users.users."${settings.username}".shell = pkgs.fish;
}
