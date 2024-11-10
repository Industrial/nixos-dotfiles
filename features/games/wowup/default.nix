{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    wowup-cf
  ];
}
