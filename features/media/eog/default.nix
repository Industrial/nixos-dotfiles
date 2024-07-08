{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Image Viewer
    eog
  ];
}
