{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    killall
  ];
}
