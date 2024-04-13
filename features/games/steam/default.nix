{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # Unfree License
    # steam
  ];
}
