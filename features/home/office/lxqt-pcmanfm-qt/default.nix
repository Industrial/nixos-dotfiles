# PCManFM-QT is a file manager for the LXQT desktop.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    lxqt.pcmanfm-qt
  ];
}
