# Video Player.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    vlc
  ];
}
