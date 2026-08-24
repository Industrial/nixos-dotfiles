{
  settings,
  pkgs,
  ...
}: {
  # Rootless-only Docker.
  #
  # The rootful daemon MUST stay disabled: with both enabled, any shell
  # without $DOCKER_HOST (cron, plain SSH non-login shells, IDE terminals)
  # silently falls back to /var/run/docker.sock, and `docker compose` then
  # creates a duplicate project on the wrong daemon (observed split-brain:
  # Traefik mounting the rootless socket ran under rootful and discovered
  # zero backends -> 404 for every vhost).
  #
  # Note that enableOnBoot = false would NOT be enough: the upstream module
  # wires systemd.sockets.docker into sockets.target unconditionally, so the
  # rootful daemon would be socket-activated on first CLI contact anyway.
  # Only virtualisation.docker.enable = false removes it entirely.
  virtualisation = {
    docker = {
      enable = false;

      rootless = {
        enable = true;
        setSocketVariable = true;

        extraPackages = with pkgs; [
          docker-buildx # buildkit builder management
          docker-compose # compose v2 plugin (if you use `docker compose`, not standalone binary)
        ];

        # Optionally customize rootless Docker daemon settings
        daemon.settings = {
          dns = ["1.1.1.1" "8.8.8.8"];
          registry-mirrors = ["https://mirror.gcr.io"];
        };
      };
    };
  };

  # Rootless dockerd (Go TLS) does not pick up system CAs without this;
  # otherwise pulls fail with: x509: certificate signed by unknown authority
  systemd.user.services.docker.serviceConfig.Environment = [
    "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
  ];

  boot = {
    kernel = {
      sysctl = {
        "net.ipv4.ip_unprivileged_port_start" = 80;
      };
    };
  };
}
