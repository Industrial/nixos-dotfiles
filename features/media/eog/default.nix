{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # Image Viewer
    gnome.eog
  ];
}
