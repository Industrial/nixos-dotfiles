{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # Commandline Audio Player
    mpv-unwrapped
  ];
}
