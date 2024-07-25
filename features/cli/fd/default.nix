# FD is a file finder.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    fd
  ];
}
