# Navi is an interactive cheatsheet launcher for shell commands. Its binary is navi.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    navi
  ];
}
