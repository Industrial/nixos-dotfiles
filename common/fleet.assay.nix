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

    # Builders advertised to clients are exactly the builder-role hosts.
    buildersAreBuilderRole = assay.eq (lib.sort lib.lessThan (map (b: b.name) fleet.builders)) (lib.sort lib.lessThan (fleet.withRole "builder"));

    # vcache: served only by builders with a tailnet address, and a host advertises a
    # cache key only if it runs the server.
    vcacheServersAreAddressedBuilders = assay.eq (lib.filter (name: !(fleet.hasRole "builder" name && fleet.hosts.${name} ? tailscaleIp)) (runs "nix.vcache")) [];
    cacheKeysOnlyOnServers = assay.eq (lib.filter (name: !(builtins.elem name (runs "nix.vcache"))) (map (c: c.name) fleet.binaryCaches)) [];
    binaryCachesUseTheFleetPort = assay.eq (lib.all (c: lib.hasSuffix ":${toString fleet.cachePort}" c.url) fleet.binaryCaches) true;

    everyHostEnrolled = assay.eq (builtins.length fleet.operatorKeys) (builtins.length fleet.names);
  }
