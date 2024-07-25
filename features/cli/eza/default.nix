# eza is a ls replacement.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    eza
  ];
}
