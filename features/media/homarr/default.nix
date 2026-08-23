# Homarr dashboard, built from source (vendored nixpkgs PR #430235 package).
#
# Upstream publishes no binaries - only an OCI image - and has no interest in
# bare-metal support, so the packaging from the closed nixpkgs PR is vendored
# here at its known-good version. Runs as native systemd services (no Docker):
# nextjs web app + websocket server + cron tasks against a sqlite DB.
{
  lib,
  pkgs,
  ...
}: let
  name = "homarr";
  directoryPath = "/data/services/${name}";
  webPort = 7575;
  wsPort = 3001;

  sharedEnv = {
    NODE_ENV = "production";
    HOSTNAME = "0.0.0.0";
    AUTH_PROVIDERS = "credentials";
    DB_DIALECT = "sqlite";
    DB_DRIVER = "better-sqlite3";
    DB_URL = "${directoryPath}/appdata/db/db.sqlite";
    REDIS_IS_EXTERNAL = "true";
    REDIS_HOST = "127.0.0.1";
    REDIS_PORT = "6380";
    SECRET_ENCRYPTION_KEY = "a203bd976170059a5b560b8ade34fcb4951f970f94792abefbafad1377610d28";
    # Required in production: authenticates web<->tasks cron calls.
    CRON_JOB_API_KEY = "f3f603f8921ac81e6f076a13255519193e0f39f247c2ae5aa85386ae6a70c384";
    # Required by authjs (NextAuth) in production. Without it every tRPC
    # request logs `MissingSecret` and the web app answers 500.
    AUTH_SECRET = "28dfdfcf4e66e35f8c304010829df8b8af227411399e90fe56dfffdb3ebc2470";
  };

  serviceCommon = {
    User = name;
    Group = "data";
    Restart = "always";
    # 5s restarts made the icon-fetch crash loop SIGABRT every cycle and
    # burn the anonymous GitHub API quota (~3 requests per failed start).
    # 20 min keeps the loop under ~10 requests/hour, leaving headroom for
    # a successful fetch once the quota window resets.
    RestartSec = 1200;
  };

  # homarr-tasks aborts when the anonymous GitHub API quota is exhausted
  # (icon repository trees). Throttle restarts and self-heal hourly: the
  # timer gets the service one fresh attempt per hour until the rate-limit
  # window resets, instead of a 5s SIGABRT loop burning the whole quota.
in {
  environment.systemPackages = with pkgs; [
    homarr
  ];

  # External redis: homarr requires one; 6379 on this host belongs to the
  # rootless container stack, so run ours on 6380. The redis module's
  # overcommit sysctl conflicts with features/performance/memory, which
  # pins it to 0; redis's recommendation takes precedence for this instance.
  boot.kernel.sysctl."vm.overcommit_memory" = lib.mkForce 1;
  services.redis.servers.homarr = {
    enable = true;
    port = 6380;
    bind = "127.0.0.1";
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Homarr Dashboard (web)";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target" "redis-homarr.service" "homarr-wss.service"];
        wants = ["network-online.target" "redis-homarr.service"];
        requires = ["homarr-migrate.service"];
        environment =
          sharedEnv
          // {
            PORT = toString webPort;
            WEB_PORT = toString webPort;
            WEBSOCKET_PORT = toString wsPort;
          };
        serviceConfig =
          serviceCommon
          // {
            Type = "simple";
            WorkingDirectory = "${pkgs.homarr}/lib/nextjs";
            ExecStart = "${pkgs.homarr}/bin/homarr-nextjs";
          };
      };

      "homarr-wss" = {
        description = "Homarr Dashboard (websocket)";
        wantedBy = ["multi-user.target"];
        after = ["redis-homarr.service"];
        bindsTo = ["${name}.service"];
        environment =
          sharedEnv
          // {
            PORT = toString wsPort;
            WEBSOCKET_PORT = toString wsPort;
          };
        serviceConfig =
          serviceCommon
          // {
            Type = "simple";
            ExecStart = "${pkgs.homarr}/bin/homarr-wss";
          };
      };

      "homarr-tasks" = {
        description = "Homarr Dashboard (cron tasks)";
        wantedBy = ["multi-user.target"];
        after = ["redis-homarr.service"];
        bindsTo = ["${name}.service"];
        environment = sharedEnv;
        # Re-arm the hourly revive timer on every successful start.
        serviceConfig =
          serviceCommon
          // {
            Type = "simple";
            ExecStart = "${pkgs.homarr}/bin/homarr-tasks";
            ExecStartPost = "+${pkgs.systemd}/bin/systemctl start ${name}-tasks-revive.timer";
          };
      };

      "homarr-migrate" = {
        description = "Homarr Dashboard (db migrations)";
        after = ["redis-homarr.service"];
        before = ["${name}.service"];
        environment = sharedEnv;
        serviceConfig = {
          Type = "oneshot";
          User = name;
          Group = "data";
          ExecStart = "${pkgs.homarr}/bin/homarr-migrate";
          RemainAfterExit = true;
        };
      };
    };
    timers."${name}-tasks-revive" = {
      description = "Hourly revive attempt for homarr-tasks";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "hourly";
        RandomizedDelaySec = "5m";
        Unit = "${name}-tasks.service";
        Persistent = true;
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
