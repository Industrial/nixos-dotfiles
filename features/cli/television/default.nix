# Television fuzzy-finds across channels. It's a replacement for fzf.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    television
  ];
}
