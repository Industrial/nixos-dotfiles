# Meld is a diff viewer.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nodejs_20
    nodePackages.npm
    nodePackages.pnpm
  ];
}
