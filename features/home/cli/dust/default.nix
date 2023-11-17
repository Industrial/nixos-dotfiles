# Dust is a file size display. Better then df.
{pkgs, ...}: {
  home.packages = with pkgs; [
    du-dust
  ];
}
