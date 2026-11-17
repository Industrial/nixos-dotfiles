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

          # Images, layers and build cache live off the 2TB NVMe: a 746GB
          # docker root had taken the SSD to 97% full. /data is the 16TB
          # array, so the cache can grow without threatening root. The
          # directory must exist and be owned by the rootless user.
          # Trade-off: /data is spinning rust, so cold builds are slower.
          data-root = "/data/docker-cache";
        };
      };
    };
  };

  systemd.user.services.docker = {
    # Rootless dockerd (Go TLS) does not pick up system CAs without this;
    # otherwise pulls fail with: x509: certificate signed by unknown authority
    serviceConfig.Environment = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];

    # Do not bounce the daemon during activation. Two independent reasons:
    #
    # 1. It made `bin/fleet deploy drakkar` fail. containerd's boltdb
    #    (meta.db) lives under data-root on /data -- spinning rust -- and
    #    opening it cold while activation is hammering the array takes >15s.
    #    dockerd's wait for containerd is a hardcoded 15s (startupTimeout in
    #    libcontainerd/supervisor), not reachable from daemon.json, so the
    #    start dies with "timeout waiting for containerd to start". systemd
    #    then restarts it (Restart=always, RestartSec=2) and it comes up fine
    #    ~20s later -- but switch-to-configuration has already seen the failed
    #    job, exits 4, and deploy-rs reports the whole deploy as failed. Both
    #    `status 4` activations in the journal (2026-11-15, 2026-11-17) were
    #    this, and nothing else.
    #
    # 2. Restarting rootless dockerd kills every running container in the
    #    session, which is not something a system deploy should do. nixpkgs
    #    draws the same line for units whose restart tears down sessions --
    #    see systemd-user-sessions in systemd/user.nix.
    #
    # Cost: the daemon keeps running the previous moby until it is restarted
    # by hand (`systemctl --user restart docker`) or at next login. Only a
    # *running* instance is skipped; a stopped docker.service is still started
    # normally.
    restartIfChanged = false;
  };

  boot = {
    kernel = {
      sysctl = {
        "net.ipv4.ip_unprivileged_port_start" = 80;
      };
    };
  };
}
