{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    foliate
  ];
}
