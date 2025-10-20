# Chat.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    signal-desktop
  ];
}
