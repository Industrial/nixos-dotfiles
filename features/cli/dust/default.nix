{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dust
  ];
}
