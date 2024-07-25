# Music Library & Player.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    spotify
  ];
}
