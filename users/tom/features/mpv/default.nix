{
  pkgs,
  config,
  ...
}: {
  home.packages = with pkgs; [
    # Commandline Audio Player
    mpv-unwrapped
  ];
}
