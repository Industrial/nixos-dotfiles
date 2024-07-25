# Okular is a universal document viewer.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    okular
  ];
}
