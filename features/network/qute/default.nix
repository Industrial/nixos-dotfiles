{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    qutebrowser
    #qutebrowser-qt5
  ];
}
