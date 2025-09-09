{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    anki
    anki-bin
    anki-sync-server
  ];
}
