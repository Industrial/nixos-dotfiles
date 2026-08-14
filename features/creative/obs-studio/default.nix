# OBS Studio with virtual camera (v4l2loopback) and background-removal plugin.
# programs.obs-studio.enable installs the wrapped package; do not also add pkgs.obs-studio.
{pkgs, ...}: {
  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-backgroundremoval
      obs-pipewire-audio-capture
    ];
  };

  environment.systemPackages = with pkgs; [
    v4l-utils
  ];
}
