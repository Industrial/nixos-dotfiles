# Colocated suite: V-268102 — notification at 90% audit volume.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268102.nix {};
in
  assay.suite "stig-V-268102" {
    actionIsSyslog = assay.eq mod.security.auditd.settings.admin_space_left_action "syslog";
    doesNotStopTheSystem =
      assay.eq (builtins.elem mod.security.auditd.settings.admin_space_left_action ["HALT" "SINGLE" "SUSPEND"]) false;
  }
