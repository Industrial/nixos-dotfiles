# Colocated suite: V-268097 — cron configuration changes audited.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268097.nix {};
in
  assay.suite "stig-V-268097" {
    rules = assay.eq mod.security.audit.rules [
      "-w /var/cron/tabs/ -p wa -k services"
      "-w /var/cron/cron.allow -p wa -k services"
      "-w /var/cron/cron.deny -p wa -k services"
    ];
    # Watch rules, not syscall rules — all three must be write+attribute watches.
    allAreWriteAttrWatches = assay.eq (builtins.all (r: builtins.match "-w .* -p wa -k services" r != null) mod.security.audit.rules) true;
    watchesNixCronPaths = assay.eq (builtins.all (r: builtins.match ".*/var/cron/.*" r != null) mod.security.audit.rules) true;
  }
