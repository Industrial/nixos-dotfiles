# Colocated suite for features/nix/vdeploy/test-rollback.nix, the forced-failing health
# check VM test (#160). Evaluates the test's node, so the claims are about the machine
# under test; no VM is booted here (`nix build .#checks.x86_64-linux.vdeploy-rollback-vm`
# runs it).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  rollback = import ./test-rollback.nix {inherit pkgs;};
  r = rollback.nodes.machine;
  spec = name: r.specialisation.${name}.configuration;
  probesOf = c: builtins.attrNames c.features.nix.vhealth.probes;
in
  assay.suite "vdeploy-rollback-vm-test" {
    named = assay.eq rollback.name "vm-test-run-vdeploy-rollback-vm";
    # Deploy mode from boot, and a generation whose probe cannot pass.
    inDeployMode = assay.eq r.features.nix.vdeploy.mode "deploy";
    brokenHasADeadPort = assay.eq [(builtins.elem "dead-port" (probesOf (spec "broken"))) ((spec "broken").systemd.services ? liar)] [true true];
    goodHasNone = assay.eq (builtins.elem "dead-port" (probesOf (spec "good"))) false;
    stuckNeverComesUp = assay.eq (builtins.elem "never-up" (probesOf (spec "stuck"))) true;
    shortHealthWindow = assay.eq r.features.nix.vdeploy.healthWindow "10s";
    byHandApply = assay.eq (nixos.hasPackage r "vdeploy-apply") true;
  }
