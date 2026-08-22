{
  lib,
  pkgs,
  ...
}: {
  # Host postgres must not bind 5432: mimir's rootless containers (logto-db)
  # already own it (5433 is yb-tserver's).
  services.postgresql.settings.port = 5434;

  # The upstream module writes db.host="" expecting unix-socket peer auth,
  # but invidious' crystal-pg resolves that to localhost TCP instead, so
  # grant the invidious role passwordless loopback access explicitly.
  services.postgresql.authentication = lib.concatStringsSep "\n" [
    "local all all peer"
    "host invidious invidious 127.0.0.1/32 trust"
    "host invidious invidious ::1/128 trust"
    "host all all 127.0.0.1/32 scram-sha-256"
    "host all all ::1/128 scram-sha-256"
  ];

  services.invidious = {
    enable = true;
    port = 4000;
  };
}
