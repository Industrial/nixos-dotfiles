{pkgs, ...}: {
  # Enable system fish.
  programs.fish.enable = true;
  users.users.tom.shell = pkgs.fish;

  # TODO: Put in system fish feature
  environment.systemPackages = with pkgs; [
    base16-schemes
    exa
    fishPlugins.bass
    fishPlugins.fzf
    fzf
    starship
  ];
}
