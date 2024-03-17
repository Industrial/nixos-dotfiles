# FD is a file finder.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    fd
  ];
}
