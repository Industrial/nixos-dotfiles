# Meld is a diff viewer.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    meld
  ];
}
