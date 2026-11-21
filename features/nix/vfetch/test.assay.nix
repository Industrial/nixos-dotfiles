# Colocated suite for features/nix/vfetch/test.nix — the VM test that substitutes a
# path through vfetch serve.
#
# Evaluates the test's nodes (no VM is booted here; `nix build .#checks.x86_64-linux.vfetch-vm`
# runs it): the client runs the feature with the cache behind it, and the cache has the
# payload the client lacks.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test.nix {inherit pkgs;};
  inherit (test.nodes) cache client;
in
  assay.suite "vfetch-vm-test" {
    named = assay.eq test.name "vm-test-run-vfetch-vm";
    clientRunsTheFeature = assay.eq (client.systemd.services ? vfetch-serve) true;
    clientAsksVfetchFirst =
      assay.eq (builtins.head client.nix.settings.substituters) "http://127.0.0.1:5101";
    clientHasTheCacheBehindIt = assay.eq (builtins.elem "http://cache:5000" client.nix.settings.substituters) true;
    cacheHasThePayload = assay.eq (map (d: d.name) cache.system.extraDependencies) ["vfetch-payload"];
    cacheServesWithNixServe = assay.eq cache.services.nix-serve.enable true;
  }
