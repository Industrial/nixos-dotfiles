# GitButler is a modern Git client with virtual branches.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    gitbutler
  ];
}
