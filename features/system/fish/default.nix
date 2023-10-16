{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Not installable with home manager.
    fishPlugins.bass
    fishPlugins.fzf
  ];
}
