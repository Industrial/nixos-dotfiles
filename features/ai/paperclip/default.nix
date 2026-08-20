# Paperclip — https://paperclipai.net/
# Open-source control plane for AI agents (org charts, goals, budgets, heartbeats).
# Docs: https://docs.paperclip.ing/guides/getting-started/installation/
# Requires Node.js 20+. Do not run as root (embedded Postgres refuses admin users).
{pkgs, ...}: {
  environment.systemPackages = [
    pkgs.nodejs_22
    (pkgs.callPackage ./package.nix {})
  ];
}
