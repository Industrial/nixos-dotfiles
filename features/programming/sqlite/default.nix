# SqLite.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    sqlite
  ];
}
