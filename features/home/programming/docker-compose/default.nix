# Docker Compose.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    docker-compose
  ];
}
