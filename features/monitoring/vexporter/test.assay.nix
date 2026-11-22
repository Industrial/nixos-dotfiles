# Colocated suite for features/monitoring/vexporter/test.nix (GH-248). Evaluates the test's
# node; no VM is booted here (`nix build .#checks.x86_64-linux.vexporter-vm` runs it).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test.nix {inherit pkgs;};
  m = test.nodes.machine;
in
  assay.suite "vexporter-vm-test" {
    named = assay.eq test.name "vm-test-run-vexporter-vm";
    # mimir's hardening (auditd is one of base-safe's controls).
    stigBaseSafe = assay.eq m.security.auditd.enable true;
    runsAsItsOwnUser = assay.eq m.systemd.services.vexporter.serviceConfig.User "vexporter";
    aNormalReader = assay.eq m.users.users.alice.isNormalUser true;
  }
