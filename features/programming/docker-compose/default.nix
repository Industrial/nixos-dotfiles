# Docker Compose.
{
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}
