# Insomnia is a HTTP test tool.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    insomnia
  ];
}
