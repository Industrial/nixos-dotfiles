# Homarr dashboard, built from source (vendored nixpkgs PR #430235 package).
#
# Upstream publishes no binaries - only an OCI image - and has no interest in
# bare-metal support, so the packaging from the closed nixpkgs PR is vendored
# here at its known-good version. Runs as a native systemd service (no Docker):
# nextjs web app + websocket server + cron tasks against a sqlite DB.
{
  pkgs,
  ...
}: let
  name = "homarr";
  directoryPath = "/data/services/${name}";
  webPort = 7575;
  wsPort = 3001;
in {
  environment.systemPackages = with pkgs; [
    homarr
  ];

  # External redis: homarr requires one; 6379 on this host belongs to the
  # rootless container stack, so run ours on 6380.
  services.redis.servers.homarr = {
    enable = true;
    port = 6380;
    bind = "127.0.0.1";
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Homarr Dashboard";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target" "redis-homarr.service"];
        wants = ["network-online.target" "redis-homarr.service"];
        environment = {
          NODE_ENV = "production";
          PORT = toString webPort;
          WEB_PORT = toString webPort;
          WEBSOCKET_PORT = toString wsPort;
          HOSTNAME = "0.0.0.0";
          AUTH_PROVIDERS = "credentials";
          DB_DIALECT = "sqlite";
          DB_DRIVER = "better-sqlite3";
          DB_URL = "${directoryPath}/appdata/db/db.sqlite";
          REDIS_IS_EXTERNAL = "true";
          REDIS_HOST = "127.0.0.1";
          REDIS_PORT = "6380";
          SECRET_ENCRYPTION_KEY = "a203bd976170059a5b560b8ade34fcb4951f970f94792abefbafad1377610d28";
        };
        serviceConfig = {
          Type = "simple";
          User = name;
          Group = "data";
          WorkingDirectory = "${pkgs.homarr}/lib/nextjs";
          StateDirectory = "${name}";
          ExecStart = ''
            ${pkgs.homarr}/bin/homarr-nextjs \
              --env KEYCLOAK_CLIENT_SECRET=unused
          '';
          Restart = "always";
          RestartSec = 5;
        };
        preStart = ''
          # Run DB migrations before start (idempotent upstream).
          ${pkgs.homarr}/bin/homarr-migrate || true
          # Websocket + cron tasks run alongside the web server.
          ${pkgs.homarr}/bin/homarr-wss &
          ${pkgs.homarr}/bin/homarr-tasks &
        '';
      };
    };
    tmpfiles = {
      rules = [
        "d ${directoryPath} 0770 ${name} data - -"
        "d ${directoryPath}/appdata 0770 ${name} data - -"
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [webPort];

  users = {
    users = {
      "${name}" = {
        isSystemUser = true;
        home = "/home/${name}";
        createHome = true;
        group = "${name}";
        extraGroups = ["data"];
      };
    };
    groups = {
      "${name}" = {};
    };
  };
}
