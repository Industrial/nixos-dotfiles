# Colocated suite for features/media/arr-wiring.nix.
# Imports the module with minimal stubs (writeShellScript / writePython3 return
# {name, text}-shaped attrsets) so the pure wiring logic evaluates without nixpkgs.
let
  assay = import ./../../common/assay/default.nix;
  keys = import ./api-keys.nix;
  apps = ["lidarr" "prowlarr" "radarr" "readarr" "sonarr"];

  fakeWriter = name: text: {inherit name text;};
  pkgs' = {
    writeShellScript = fakeWriter;
    writers.writePython3 = fakeWriter;
  };
  lib' = {
    inherit (builtins)
      attrNames
      concatStringsSep
      mapAttrs
      removeAttrs
      toJSON
      ;
    concatMapStringsSep = sep: f: xs:
      builtins.concatStringsSep sep (map f xs);
  };

  mod = import ./arr-wiring.nix {
    pkgs = pkgs';
    lib = lib';
    config = {};
  };
  svc = mod.systemd.services;
  seedText = svc."arr-api-key-seed".serviceConfig.ExecStart.text;
  syncEnv = svc.prowlarr-sync.environment;

  # Each app must appear as "<app> <its declared key>" in the seed script.
  seedLinesCorrect = builtins.all
    (a: builtins.match ".*${a} ${keys.${a}}.*" seedText != null)
    apps;
  targets = builtins.fromJSON syncEnv.TARGETS;
in
  assay.suite "arr-wiring" {
    bothUnitsDeclared =
      assay.eq (builtins.attrNames svc) ["arr-api-key-seed" "prowlarr-sync"];
    seedWantedByBoot =
      assay.eq svc."arr-api-key-seed".wantedBy ["multi-user.target"];
    seedOrderedAfterArrUnits = assay.eq
      (builtins.all
        (u: builtins.elem u svc."arr-api-key-seed".after)
        (map (a: "${a}.service") apps))
      true;
    seedScriptPairsKeysWithApps = assay.eq seedLinesCorrect true;
    seedScriptIdempotentSkip = assay.eq
      (builtins.match ".*already match.*" seedText != null)
      true;
    syncOrderedAfterSeed = assay.eq
      (builtins.elem "arr-api-key-seed.service" svc.prowlarr-sync.after)
      true;
    syncIsOneshot = assay.eq svc.prowlarr-sync.serviceConfig.Type "oneshot";
    syncTargetsUseDeclaredKeys = assay.eq
      (targets.radarr.key == keys.radarr && targets.sonarr.key == keys.sonarr)
      true;
    syncTargetPortsMatchRegistry = assay.eq
      (targets.radarr.url == "http://127.0.0.1:7878"
        && !targets ? prowlarr)
      true;
  }
