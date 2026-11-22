# Colocated suite for features/nix/vdeploy/test-crash.nix, the crash-in-the-health-window
# reboot test (GH-225). Evaluates the test's node, so the claims are about the machine under
# test; no VM is booted here (`nix build .#checks.x86_64-linux.vdeploy-crash-vm` runs it).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test-crash.nix {inherit pkgs;};
  t = test.nodes.machine;
  spec = name: t.specialisation.${name}.configuration;
  probesOf = c: builtins.attrNames c.features.nix.vhealth.probes;
in
  assay.suite "vdeploy-crash-vm-test" {
    named = assay.eq test.name "vm-test-run-vdeploy-crash-vm";
    # The hosts' boot path: EFI firmware, systemd-boot, the kernel from the loader entry.
    bootsThroughEfiAndSystemdBoot =
      assay.eq [t.virtualisation.useBootLoader t.virtualisation.useEFIBoot t.boot.loader.systemd-boot.enable] [true true true];
    # Hardened as mimir is (STIG base-safe: auditd is one of its controls), restricted daemon.
    stigBaseSafe = assay.eq t.security.auditd.enable true;
    restrictedDaemon = assay.eq (builtins.elem "@wheel" t.nix.settings.allowed-users) true;
    deployMode = assay.eq [t.features.nix.vdeploy.mode t.features.nix.vdeploy.healthWindow] ["deploy" "10m"];
    # good is healthy; slow waits on a probe nothing serves, so its apply stays in the window.
    probes = assay.eq [(probesOf (spec "good")) (probesOf (spec "slow"))] [["nix-daemon" "web"] ["never-up" "nix-daemon" "web"]];
  }
