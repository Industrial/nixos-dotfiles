# vit is a taskwarrior client.
{pkgs, ...}: {
  home.packages = with pkgs; [
    vit
  ];
}
