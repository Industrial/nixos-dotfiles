# Zoxide jumps to frecent directories. It's a replacement for cd.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    zoxide
  ];
}
