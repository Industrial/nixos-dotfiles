# Carapace — multi-shell completion engine covering 1000+ commands.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    carapace
  ];
}
