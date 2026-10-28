# Colocated suite: V-268101 — notification at 75% audit volume.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268101.nix {};
in
  assay.suite "stig-V-268101" {
    actionIsSyslog = assay.eq mod.security.auditd.settings.space_left_action "syslog";

    # Not SUSPEND/HALT/SINGLE: those stop auditing or the host rather than notifying, which
    # is this control's whole purpose. The action controls are V-268105 and V-268106.
    doesNotStopTheSystem =
      assay.eq (builtins.elem mod.security.auditd.settings.space_left_action ["HALT" "SINGLE" "SUSPEND"]) false;
  }
