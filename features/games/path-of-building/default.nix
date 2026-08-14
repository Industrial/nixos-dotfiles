{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    rusty-path-of-building
  ];
}
