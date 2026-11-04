# Delta is a syntax-highlighting pager for git, diff and grep output.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    delta
  ];
}
