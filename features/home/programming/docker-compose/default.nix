# Docker Compose.
{pkgs, ...}: {
  home.packages = with pkgs; [
    docker-compose
  ];
}
