{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    path-of-building
  ];
}
