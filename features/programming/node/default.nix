# Node.js development environment
# Note: npm is included with nodejs by default
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nodejs
    pnpm
  ];
}
