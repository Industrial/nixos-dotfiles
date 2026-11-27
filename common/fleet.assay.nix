# Suite for common/fleet.nix — the inventory, and that hosts agree with it.
#
# The inventory says what each host IS (roles); hosts/*/configuration.nix says what each
# host RUNS (features). These claims keep the two from drifting: a role without its
# feature, or a feature on a host without the role, fails here.
let
  assay = import ./assay/default.nix;
  nixos = import ./assay/nixos.nix;
  inherit (nixos) lib;
  fleet = import ./fleet.nix;
  features = import ../lib/features.nix {inherit lib;};

  hostDir = name: ../hosts + "/${name}";
  selection = name:
    features.evalSelection {
      modules = [
        (hostDir name + "/configuration.nix")
        {disabledModules = map (f: hostDir name + "/${f}") ["disko.nix" "filesystems.nix" "hardware.nix"];}
        # As features/nixos/networking sets it from settings.hostname (read by vpush's switch).
        {networking.hostName = name;}
      ];
    };
  enabled = lib.genAttrs fleet.names (name: features.enabledFeatures (selection name));
  runs = feature: lib.filter (name: builtins.elem feature enabled.${name}) fleet.order;
in
  assay.suite "fleet" {
    # Every inventory host has a hosts/<name>/ directory, and vice versa.
    hostsMatchDirectories = assay.eq fleet.names (lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir ../hosts)));

    orderCoversEveryHost = assay.eq (lib.sort lib.lessThan fleet.order) fleet.names;

    relayRoleMatchesFeature = assay.eq (runs "fleet.remote-desktop-relay") (fleet.withRole "remote-desktop-relay");
    nfsServerRoleMatchesFeature = assay.eq (runs "storage.nfs-server") (fleet.withRole "nfs-server");
    monitoringRoleMatchesFeature = assay.eq (runs "monitoring.prometheus") (fleet.withRole "monitoring");
    builderRoleMatchesFeature = assay.eq (runs "fleet.nix-remote-builder-server") (fleet.withRole "builder");

    # Mounts ⇔ exported to: a host runs the NFS client exactly when mimir exports to it.
    nfsClientRoleMatchesFeature = assay.eq (runs "storage.nfs-client") fleet.nfsClients;

    # Work machines carry no personal data: no NFS client, never in the export list.
    workHostsHaveNoNfs = assay.eq (lib.filter (name: builtins.elem "storage.nfs-client" enabled.${name} || builtins.elem name fleet.nfsClients) (fleet.withRole "work")) [];

    nfsClientsHaveAddress = assay.eq (lib.all (name: fleet.hosts.${name} ? tailscaleIp) fleet.nfsClients) true;

    # Builders advertised to clients are exactly the online builder-role hosts.
    buildersAreBuilderRole = assay.eq (lib.sort lib.lessThan (map (b: b.name) fleet.builders)) (lib.sort lib.lessThan (lib.filter fleet.isOnline (fleet.withRole "builder")));

    # huginn and muninn are out of reach (GH-252): clients neither build on them nor ask
    # them for paths, drakkar stays, and the hosts keep their roles (their own configs
    # still evaluate and run the builder server). Hosts without the field are online.
    offlineHosts = assay.eq (lib.filter (n: !(fleet.isOnline n)) fleet.order) ["huginn" "muninn"];
    offlineHostsAreNotBuilders = assay.eq (lib.filter (b: !(fleet.isOnline b.name)) fleet.builders) [];
    offlineHostsServeNoCache = assay.eq (lib.filter (c: !(fleet.isOnline c.name)) fleet.binaryCaches) [];
    drakkarIsABuilder = assay.eq (builtins.elem "drakkar" (map (b: b.name) fleet.builders)) true;
    offlineHostsKeepTheirRoles = assay.eq (map (fleet.hasRole "builder") ["huginn" "muninn"]) [true true];
    onlineByDefault = assay.eq (map fleet.isOnline ["drakkar" "mimir"]) [true true];

    # drakkar and mimir get their builders only from nix-remote-builder-client (whose
    # list is fleet.builders, its own suite): mimir runs it, drakkar does not, so
    # drakkar's nix.buildMachines is empty and mimir's is the online builders.
    builderClients = assay.eq (lib.filter (n: builtins.elem n ["drakkar" "mimir"]) (runs "fleet.nix-remote-builder-client")) ["mimir"];

    # vcache: served only by builders with a tailnet address, and a host advertises a
    # cache key only if it runs the server.
    vcacheServersAreAddressedBuilders = assay.eq (lib.filter (name: !(fleet.hasRole "builder" name && fleet.hosts.${name} ? tailscaleIp)) (runs "nix.vcache")) [];
    cacheKeysOnlyOnServers = assay.eq (lib.filter (name: !(builtins.elem name (runs "nix.vcache"))) (map (c: c.name) fleet.binaryCaches)) [];
    binaryCachesUseTheFleetPort = assay.eq (lib.all (c: lib.hasSuffix ":${toString fleet.cachePort}" c.url) fleet.binaryCaches) true;

    # Compartment trust facts (GH-421): every host carries all of them, the tier is from a
    # closed set and follows the TPM, and no attestation root is pinned yet (DICE roots
    # are enrolled later, like operatorKey).
    trustFactsOnEveryHost = assay.eq (lib.filter (n: let
      h = fleet.hosts.${n};
    in
      !(h ? trustTier && h ? tpm2 && h ? attestationRoot && h ? cpu && lib.attrNames h.cpu == ["model" "sevSnp" "tdx" "vendor"]))
    fleet.order) [];
    trustTiersAreKnown = assay.eq (lib.filter (n: !(builtins.elem fleet.hosts.${n}.trustTier ["local-hw-attested" "local-unattested"])) fleet.order) [];
    hwAttestedIffTpm2 = assay.eq (lib.filter (n: fleet.hosts.${n}.trustTier == "local-hw-attested") fleet.order) (lib.filter (n: fleet.hosts.${n}.tpm2) fleet.order);
    cpuVendorsAreKnown = assay.eq (lib.filter (n: !(builtins.elem fleet.hosts.${n}.cpu.vendor ["amd" "intel"])) fleet.order) [];
    # SEV-SNP is AMD-only and TDX Intel-only.
    confidentialVmFlagsMatchVendor = assay.eq (lib.filter (n: let
      c = fleet.hosts.${n}.cpu;
    in
      (c.sevSnp && c.vendor != "amd") || (c.tdx && c.vendor != "intel"))
    fleet.order) [];
    # Measured 2026-11-27: consumer parts only, so no host can run confidential VMs.
    noConfidentialVmHostsToday = assay.eq (lib.filter (n: fleet.hosts.${n}.cpu.sevSnp || fleet.hosts.${n}.cpu.tdx) fleet.order) [];
    noAttestationRootsYet = assay.eq (lib.filter (n: fleet.hosts.${n}.attestationRoot != null) fleet.order) [];

    everyHostEnrolled = assay.eq (builtins.length fleet.operatorKeys) (builtins.length fleet.names);

    # vpush pushes automatically from every builder-role host that is not a cache: today
    # that is every builder but drakkar. Never the cache, never a non-builder, and nobody
    # at all on an inventory with no other cache to push to.
    pushersAreNonCacheBuilders = let
      expected = lib.filter (n: !(builtins.elem n (map (c: c.name) fleet.binaryCaches))) (fleet.withRole "builder");
    in
      assay.eq [fleet.cachePushers (expected != [])] [expected true];
    cacheNeverPushes = assay.eq (lib.filter (c: fleet.pushesToCache c.name) fleet.binaryCaches) [];
    nonBuilderNeverPushes = assay.eq (lib.filter fleet.pushesToCache (lib.filter (n: !(fleet.hasRole "builder" n)) fleet.order)) [];
    vpushRunsOnThePushers = assay.eq (runs "nix.vpush") fleet.cachePushers;
    noCacheNoPushers = let
      noKeys = builtins.mapAttrs (_: h: removeAttrs h ["cacheKey"]) fleet.hosts;
    in
      assay.eq (lib.filter (fleet.pushesToCacheIn noKeys) fleet.order) [];
  }
