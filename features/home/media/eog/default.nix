{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # Image Viewer
    gnome.eog
  ];
}
