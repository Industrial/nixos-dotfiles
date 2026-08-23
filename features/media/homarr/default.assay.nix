# Colocated suite: homarr systemd modules with stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    homarr = "homarr";
    pkgs = {homarr = "homarr";};
    lib = {};
  };
  web = mod.systemd.services."homarr";
  wss = mod.systemd.services."homarr-wss";
  tasks = mod.systemd.services."homarr-tasks";
in
  assay.suite "homarr" {
    systemPackages = assay.eq mod.environment.systemPackages ["homarr"];
    unitDescription = assay.eq web.description "Homarr Dashboard (web)";
    runsAsServiceUser = assay.eq web.serviceConfig.User "homarr";
    dataGroup = assay.eq web.serviceConfig.Group "data";
    restartAlways = assay.eq web.serviceConfig.Restart "always";
    webPort = assay.eq web.environment.WEB_PORT "7575";
    sqliteDb = assay.eq
      (web.environment.DB_URL)
      "/data/services/homarr/appdata/db/db.sqlite";
    externalRedis = assay.eq web.environment.REDIS_IS_EXTERNAL "true";
    cronKeySet = assay.eq (web.environment ? "CRON_JOB_API_KEY") true;
    authSecretSet = assay.eq (web.environment ? "AUTH_SECRET") true;
    wssUnit = assay.eq (builtins.match ".*/bin/homarr-wss" wss.serviceConfig.ExecStart != null) true;
    tasksUnit = assay.eq (builtins.match ".*/bin/homarr-tasks" tasks.serviceConfig.ExecStart != null) true;
    # Rate-limit defence: no 5s SIGABRT loop against the GitHub API.
    restartThrottled = assay.eq tasks.serviceConfig.RestartSec 1200;
    reviveTimerDeclared = assay.eq
      (mod.systemd.timers ? "homarr-tasks-revive")
      true;
    reviveTimerHourly = assay.eq
      mod.systemd.timers."homarr-tasks-revive".timerConfig.OnCalendar
      "hourly";
    migrationsBeforeWeb = assay.eq web.requires ["homarr-migrate.service"];
    tmpfilesAppdata = assay.eq
      (builtins.any
        (r: builtins.match ".*/appdata .*" r != null)
        mod.systemd.tmpfiles.rules)
      true;
    serviceUser = assay.eq mod.users.users."homarr".isSystemUser true;
    extraGroupData = assay.eq mod.users.users."homarr".extraGroups ["data"];
  }
