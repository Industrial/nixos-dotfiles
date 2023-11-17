# FileZilla is a SFTP Client.
{pkgs, ...}: {
  home.packages = with pkgs; [
    filezilla
  ];
}
