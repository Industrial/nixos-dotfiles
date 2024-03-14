# PCManFM-QT is a file manager for the LXQT desktop.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    lxqt.pcmanfm-qt
  ];
}
