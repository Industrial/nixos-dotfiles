# Calcurse is a command line calendar.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    calcurse
  ];
}
