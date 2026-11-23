# Assay: features/nixos/etc-overlay puts /etc on the upstream overlay and carries the
# stateful files across, in and (from features.nixos, on every host) out.
#
# Evaluated with features.nixos and this feature wrapped as a host has them
# (lib/features.nix): the entry half only exists with the feature on, the exit half only
# without it, and the exit half must be there on a host that never enabled the feature.
# The behaviour itself is the VM test's: ./test-live-switch.nix.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  features = import ../../../lib/features.nix {inherit lib;};

  eval = selection:
    (nixos.evalSystem {
      modules = [(features.feature ../.) (features.feature ./.) {features.nixos.enable = true;} selection];
    })
    .config;
  off = eval {};
  on = eval {features.nixos.etc-overlay.enable = true;};
  # The rollback, as a host would write it.
  rolledBack = eval {features.nixos.etc-overlay.enable = lib.mkForce false;};
  # With audit rules loaded (mimir's STIG identity watches on /etc).
  auditOn = eval {
    features.nixos.etc-overlay.enable = true;
    security.audit.enable = true;
  };
  auditOff = eval {security.audit.enable = true;};

  scripts = cfg: cfg.system.activationScripts;
  unit = on.boot.initrd.systemd.services.etc-overlay-carry-in;
in
  assay.suite "etc-overlay" {
    offByDefault = assay.eq off.features.nixos.etc-overlay.enable false;
    offKeepsSetupEtc = assay.eq off.system.etc.overlay.enable false;

    onMountsTheMutableOverlay = assay.eq [on.system.etc.overlay.enable on.system.etc.overlay.mutable] [true true];
    # Live entry: carried in before upstream's `etc` step mounts the overlay over /etc.
    onCarriesInBeforeTheMount = assay.eq (builtins.elem "etcOverlayCarryIn" (scripts on).etc.deps) true;
    onCarriesInAfterTheUsers = assay.eq (lib.all (d: builtins.elem d (scripts on).etcOverlayCarryIn.deps) ["users" "groups" "specialfs"]) true;
    onHasNoCarryOut = assay.eq ((scripts on) ? etcOverlayCarryOut) false;
    # Cold entry: in the initrd, before the upperdir is prepared and the overlay mounted.
    coldEntryBeforeTheMount = assay.eq (lib.all (u: builtins.elem u unit.before) ["rw-etc.service" "sysroot-etc.mount"]) true;
    coldEntryReadsTheNewEtc = assay.eq unit.unitConfig.RequiresMountsFor ["/sysroot" "/run/nixos-etc-metadata"];
    coldEntryIsInTheInitrd =
      assay.eq (lib.any (p: toString p.source == toString unit.serviceConfig.ExecStart) on.boot.initrd.systemd.storePaths) true;

    # Leaving: on every generation without the overlay, ordered before setup-etc.pl.
    offCarriesOutBeforeSetupEtc = assay.eq (builtins.elem "etcOverlayCarryOut" (scripts off).etc.deps) true;
    offHasNoCarryIn = assay.eq ((scripts off) ? etcOverlayCarryIn) false;
    rollbackCarriesOut = assay.eq [rolledBack.system.etc.overlay.enable (builtins.elem "etcOverlayCarryOut" (scripts rolledBack).etc.deps)] [false true];
    # The exit half is inert until an overlay period left an upperdir to carry out.
    carryOutGuarded = assay.eq (lib.hasInfix "if [ -d /.rw-etc/upper ] && [ ! -e /.rw-etc/.exited ]" (scripts off).etcOverlayCarryOut.text) true;

    # A live switch reloads the audit rules, so the /etc watches follow the mount both ways:
    # the trigger is in the overlay generation only, and no audit unit appears without audit.
    auditRulesReloadOnTheSwitch =
      assay.eq [auditOn.systemd.services.audit-rules-nixos.restartTriggers auditOff.systemd.services.audit-rules-nixos.restartTriggers] [["etc-overlay"] []];
    noAuditUnitWithoutAudit = assay.eq (on.systemd.services ? audit-rules-nixos) false;
  }
