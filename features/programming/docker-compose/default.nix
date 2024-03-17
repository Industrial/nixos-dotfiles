# Docker Compose.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}
