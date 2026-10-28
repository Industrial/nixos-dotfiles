# Colocated suite: V-268106 — auditd acts, without halting, on an audit processing failure.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268106.nix {};
  config = fixture.evalWith [./V-268080.nix ./V-268105.nix ./V-268106.nix];
  action = mod.security.auditd.settings.disk_error_action;
in
  assay.suite "stig-V-268106" {
    diskErrorAction = assay.eq action "SYSLOG";
    reachesEvaluatedConfig = assay.eq config.security.auditd.settings.disk_error_action "SYSLOG";
    isAcceptedByTheCheck = assay.eq (builtins.elem action ["SYSLOG" "SINGLE" "HALT"]) true;
    doesNotHaltTheHost = assay.eq (action == "HALT") false;

    # Both action settings coexist.
    composesWithDiskFull = assay.eq config.security.auditd.settings.disk_full_action "SYSLOG";
  }
