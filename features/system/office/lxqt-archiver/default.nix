# LXQT Archiver is an archiving tool for the LXQT desktop environment.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    lxqt.lxqt-archiver
  ];
}
