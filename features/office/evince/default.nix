{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    evince
  ];
}
