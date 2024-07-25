{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    glogg
  ];
}
