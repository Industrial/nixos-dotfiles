# FileZilla is a SFTP Client.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    filezilla
  ];
}
