# gix (gitoxide) - Fast, safe pure Rust implementation of Git
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    gitoxide
  ];
}
