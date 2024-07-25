# Screengrab is a simple and easy-to-use screen capture program that is designed
# to integrate well with LXQt.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lxqt.screengrab
  ];
}
