# FileZilla is a SFTP Client.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    ungoogled-chromium
  ];
}