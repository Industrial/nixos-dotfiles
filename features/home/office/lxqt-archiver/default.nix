# LXQT Archiver is an archiving tool for the LXQT desktop environment.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    lxqt.lxqt-archiver
  ];
}
