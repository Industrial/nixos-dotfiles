# top replacement.
# TODO: There's probably something way better out there by now.
{pkgs, ...}: {
  home.packages = with pkgs; [
    htop
  ];
}
