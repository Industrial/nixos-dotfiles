# Node.js development environment
# Note: npm is included with nodejs_20 by default
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nodejs_20
    # npm is included with nodejs
    pnpm # Available at top level in newer nixpkgs
  ];
}
