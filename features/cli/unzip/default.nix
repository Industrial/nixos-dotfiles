# I need unzip.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    unzip
  ];
}
