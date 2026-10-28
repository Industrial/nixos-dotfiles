# Colocated suite: V-268105 — auditd acts, without halting, on a full audit volume.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268105.nix {};
  config = fixture.evalWith [./V-268080.nix ./V-268105.nix];
  action = mod.security.auditd.settings.disk_full_action;
in
  assay.suite "stig-V-268105" {
    diskFullAction = assay.eq action "SYSLOG";
    reachesEvaluatedConfig = assay.eq config.security.auditd.settings.disk_full_action "SYSLOG";

    # One of the three values the check accepts.
    isAcceptedByTheCheck = assay.eq (builtins.elem action ["SYSLOG" "SINGLE" "HALT"]) true;

    # ...and specifically not the one that powers the machine off. If someone "fixes" this to
    # match the fix text literally, this case fails and says why.
    doesNotHaltTheHost = assay.eq (action == "HALT") false;
  }
