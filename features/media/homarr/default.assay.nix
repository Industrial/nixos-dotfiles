# Colocated suite: homarr systemd module with stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    homarr = "homarr";
    pkgs = {homarr = "homarr";};
  };
  svc = mod.systemd.services."homarr";
in
  assay.suite "homarr" {
    systemPackages = assay.eq mod.environment.systemPackages ["homarr"];
    unitDescription = assay.eq svc.description "Homarr Dashboard";
    runsAsServiceUser = assay.eq svc.serviceConfig.User "homarr";
    dataGroup = assay.eq svc.serviceConfig.Group "data";
    webPort = assay.eq svc.environment.WEB_PORT "7575";
    sqliteDb = assay.eq
      (svc.environment.DB_URL)
      "/data/services/homarr/appdata/db/db.sqlite";
    externalRedis = assay.eq svc.environment.REDIS_IS_EXTERNAL "true";
    tmpfilesAppdata = assay.eq
      (builtins.any
        (r: builtins.match ".*/appdata .*" r != null)
        mod.systemd.tmpfiles.rules)
      true;
    serviceUser = assay.eq mod.users.users."homarr".isSystemUser true;
    extraGroupData = assay.eq mod.users.users."homarr".extraGroups ["data"];
  }
