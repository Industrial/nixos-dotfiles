# Meld is a diff viewer.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nodejs
    nodePackages.npm
    nodePackages.pnpm
  ];
}
