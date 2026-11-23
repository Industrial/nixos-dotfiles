# Assay: comin is the only unattended activator; this feature only guards that.
#
# The module used to define a nightly `nix flake update && nixos-rebuild switch`, gated
# behind a hard-coded `enableAutoUpdate = false`. It is gone (ADR-0006); what remains is an
# assertion that nixpkgs' own system.autoUpgrade stays off. These claims read the evaluated
# configuration: no update unit exists, and the assertion holds by default and fires when
# a host turns autoUpgrade on.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./default.nix];};
  withAutoUpgrade = nixos.eval {modules = [./default.nix {system.autoUpgrade.enable = true;}];};
  failing = c: builtins.filter (a: !a.assertion) c.assertions;
  guardFailures = c: builtins.filter (a: builtins.match ".*ADR-0006.*" a.message != null) (failing c);
in
  assay.suite "auto-update" {
    noUpdateService = assay.eq (cfg.systemd.services ? nixos-auto-update) false;
    noUpdateTimer = assay.eq (cfg.systemd.timers ? nixos-auto-update) false;
    # Nothing else sneaks in: the unit sets match an empty system's.
    addsNoServices =
      assay.eq (builtins.attrNames cfg.systemd.services) (builtins.attrNames nixos.baseline.systemd.services);
    addsNoTimers =
      assay.eq (builtins.attrNames cfg.systemd.timers) (builtins.attrNames nixos.baseline.systemd.timers);

    # The guard: holds on a default system, fires (and cites the policy) with autoUpgrade on.
    guardHoldsByDefault = assay.eq (guardFailures cfg) [];
    guardFiresOnAutoUpgrade = assay.eq (builtins.length (guardFailures withAutoUpgrade)) 1;
    guardNamesTheWorkflow =
      assay.eq (builtins.match ".*vbump[.]yml.*" (builtins.head (guardFailures withAutoUpgrade)).message != null) true;
  }
