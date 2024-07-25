# FileZilla is a SFTP Client.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    ungoogled-chromium
  ];
}
