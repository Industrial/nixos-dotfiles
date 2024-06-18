# Aria2 is a lightweight multi-protocol & multi-source command-line download utility.
# It supports HTTP/HTTPS, FTP, SFTP, BitTorrent and Metalink.
# You can use Aria2 for downloading files in a wide range of applications.
# Examples:
# * Download a single file:
#   $ aria2c http://example.org/my-linux.iso
# * Download multiple files:
#   $ aria2c http://example.org/file1.zip http://example.org/file2.zip
# * Download using a Metalink file:
#   $ aria2c -M mydownloads.meta4
# * Download a BitTorrent file:
#   $ aria2c mytorrent.torrent
{
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    aria2
  ];
}
