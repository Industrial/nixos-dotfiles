# Colocated suite for features/nix/vdeploy/test-evalcache.nix, the eval cache VM test
# (GH-243). Evaluates the test's nodes, so the claims are about the machines under test; no
# VM is booted here (`nix build .#checks.x86_64-linux.vdeploy-evalcache-vm` runs it).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (pkgs) lib;

  test = import ./test-evalcache.nix {inherit pkgs;};
  c = test.nodes.consumer;
  on = c.specialisation.cache.configuration;
  exec = n: n.systemd.services.vdeploy.serviceConfig.ExecStart;
in
  assay.suite "vdeploy-evalcache-vm-test" {
    named = assay.eq test.name "vm-test-run-vdeploy-evalcache-vm";
    # Boots WITHOUT the eval cache; the `cache` specialisation switches it in live.
    bootsWithoutTheCache =
      assay.eq [(lib.hasInfix "--no-eval-cache" (exec c)) (lib.hasInfix "--no-eval-cache" (exec on)) (lib.hasInfix "--eval-cache http://cache:5100" (exec on))] [true false true];
    # Hardened as mimir is (STIG base-safe: auditd is one of its controls), restricted daemon.
    stigBaseSafe = assay.eq c.security.auditd.enable true;
    restrictedDaemon = assay.eq (builtins.elem "@wheel" c.nix.settings.allowed-users) true;
    # The consumer substitutes from the cache only.
    substitutesFromTheCache = assay.eq c.nix.settings.substituters ["http://cache:5100"];
    # The cache serves vci's records.
    cacheServesRecords = assay.eq (test.nodes.cache.systemd.services.vcache.environment.VCACHE_VEVAL_DIR or null) "/var/lib/vci/veval";
  }
