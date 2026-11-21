# Colocated suite for features/nix/vpush/test.nix — the three-node VM test (builder,
# cache, client) of pushing builds into vcache.
#
# Evaluates the test's nodes (no VM is booted here; `nix build .#checks.x86_64-linux.vpush-vm`
# runs it), so these claims are about the machines under test: the builder runs vpush
# against the cache, the cache runs vcache and trusts the pushing user, and the client
# has no substituter of its own.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test.nix {inherit pkgs;};
  inherit (test.nodes) builder cache client;
in
  assay.suite "vpush-vm-test" {
    named = assay.eq test.name "vm-test-run-vpush-vm";

    builderRunsVpush = assay.eq [(builder.systemd.services ? vpush) (builder.nix.settings ? post-build-hook)] [true true];
    builderPushesToTheCacheNode = assay.eq builder.features.nix.vpush.sshDestination "tom@cache";
    builderHasTheMidSizeInputs = let
      names = map (d: d.pname or d.name) builder.system.extraDependencies;
    in
      assay.eq (map (n: builtins.elem n names) ["ruby" "nodejs-slim"]) [true true];

    cacheServesVcache = assay.eq [(cache.systemd.services ? vcache) cache.services.openssh.enable] [true true];
    cacheTrustsThePusher = assay.eq (builtins.elem "tom" cache.nix.settings.trusted-users) true;
    cacheHasNoVpush = assay.eq (cache.systemd.services ? vpush) false;

    # The fresh store substitutes from vcache only: nothing configured to fall back to.
    clientHasNoSubstituters = assay.eq client.nix.settings.substituters [];
  }
