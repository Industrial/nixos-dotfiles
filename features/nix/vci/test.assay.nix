# Colocated suite for features/nix/vci/test.nix, the VM test of the fleet CI (GH-242).
# Evaluates the test's nodes, so the claims are about the machines under test; no VM is
# booted here (`nix build .#checks.x86_64-linux.vci-vm` runs it).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (pkgs) lib;

  test = import ./test.nix {inherit pkgs;};
  cache = test.nodes.cache;
  on = cache.specialisation.vci.configuration;
in
  assay.suite "vci-vm-test" {
    named = assay.eq test.name "vm-test-run-vci-vm";
    # Booted WITHOUT vci, switched into it live by the specialisation.
    bootsWithout = assay.eq [cache.systemd.services.vci.enable on.systemd.services.vci.enable] [false true];
    # A restricted daemon, as on every host: vci is allowed, never trusted.
    restrictedLikeTheFleet = assay.eq (lib.sort lib.lessThan on.nix.settings.allowed-users) ["@wheel" "vci"];
    # The cache serves its store: vcache on the node that builds.
    cacheServes = assay.eq on.systemd.services.vcache.enable true;
    # The forge is local: no network.
    localForge = assay.eq [on.features.nix.vci.url on.features.nix.vci.pullsUrl] ["file:///srv/repo.git" "file:///srv/pulls.json"];
    statusesOff = assay.eq on.features.nix.vci.statusTokenFile null;
    # veval (GH-243): the cache serves vci's records from vci's state directory.
    servesVevalRecords = assay.eq (on.systemd.services.vcache.environment.VCACHE_VEVAL_DIR or null) "/var/lib/vci/veval";
  }
