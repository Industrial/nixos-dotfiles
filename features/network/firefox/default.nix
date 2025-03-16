# The web browser.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    librewolf
  ];
}
