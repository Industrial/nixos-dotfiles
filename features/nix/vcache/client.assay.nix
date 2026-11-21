# Colocated suite for features/nix/vcache/client.nix — fleet caches as substituters, read
# from common/fleet.nix, never the host's own.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  fleet = import ../../../common/fleet.nix;
  features = import ../../../lib/features.nix {inherit lib;};

  sample = {
    name = "drakkar";
    url = "http://${fleet.hosts.drakkar.tailscaleIp}:${toString fleet.cachePort}";
    publicKey = "drakkar-vcache-1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  evalAs = hostname: caches:
    (nixos.eval {
      modules = [./client.nix {features.nix.vcache.client.caches = caches;}];
      settings.hostname = hostname;
    }).nix.settings;
  fromFleet =
    (nixos.eval {
      modules = [./client.nix];
    }).nix.settings;
  elsewhere = evalAs "huginn" [sample];
  itself = evalAs "drakkar" [sample];
  base = (nixos.eval {modules = [];}).nix.settings;

  inBase = features.enabledFeatures (features.evalSelection {modules = [{profiles.base.enable = true;}];});
in
  assay.suite "vcache-client" {
    # Every host carries the client through the base profile; turning it off is the rollback.
    onInTheBaseProfile = assay.eq (builtins.elem "nix.vcache.client" inBase) true;

    # By default the caches are fleet.nix's: builders that published a key.
    defaultsToTheFleet = assay.eq (map (c: c.url) fleet.binaryCaches) (lib.subtractLists base.substituters fromFleet.substituters);
    fleetCachesAreBuildersWithKeys = assay.eq (lib.all (c: fleet.hasRole "builder" c.name && fleet.hosts.${c.name}.cacheKey == c.publicKey) fleet.binaryCaches) true;

    addsTheCacheAndItsKey =
      assay.eq [(builtins.elem sample.url elsewhere.substituters) (builtins.elem sample.publicKey elsewhere.trusted-public-keys)] [true true];
    boundsTheConnectTimeout = assay.eq elsewhere.connect-timeout 5;
    # The upstream caches stay, so an unreachable fleet cache falls back to them.
    keepsCacheNixosOrg = assay.eq (builtins.elem "https://cache.nixos.org/" elsewhere.substituters || builtins.elem "https://cache.nixos.org" elsewhere.substituters) true;

    neverItself =
      assay.eq [(builtins.elem sample.url itself.substituters) (builtins.elem sample.publicKey itself.trusted-public-keys)] [false false];
    noCachesNoChange = assay.eq [(evalAs "huginn" []).substituters ((evalAs "huginn" []).connect-timeout or null)] [base.substituters (base.connect-timeout or null)];
  }
