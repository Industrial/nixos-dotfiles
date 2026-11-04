# Yazi — async terminal file manager with image, video and archive preview.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    yazi
  ];
}
