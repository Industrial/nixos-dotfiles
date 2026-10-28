# Colocated suite: V-268097 — cron configuration changes audited.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268097.nix {};
  rules = mod.security.audit.rules;
  tmpfiles = mod.systemd.tmpfiles.rules;
in
  assay.suite "stig-V-268097" {
    rules = assay.eq rules ["-w /var/cron/tabs -p wa -k services"];
    isWriteAttrWatch = assay.eq (builtins.match "-w .* -p wa -k services" (builtins.head rules) != null) true;
    watchesNixCronPath = assay.eq (builtins.match ".*/var/cron/.*" (builtins.head rules) != null) true;

    # The watch target must be provisioned, or auditctl fails the whole rules file and the
    # audit subsystem never starts. This is the pairing that makes the control safe.
    provisionsTheWatchedDirectory =
      assay.eq (builtins.any (r: builtins.match "d /var/cron/tabs .*" r != null) tmpfiles) true;
    provisionsTheParentDirectory =
      assay.eq (builtins.any (r: builtins.match "d /var/cron .*" r != null) tmpfiles) true;
    crontabsDirIsOwnerOnly =
      assay.eq (builtins.elemAt (fixture.tmpfilesFields (builtins.elemAt tmpfiles 1)) 2) "0700";

    # cron.allow and cron.deny are deliberately NOT watched. Creating an empty cron.allow to
    # satisfy a watch would tell cron that NO user may use cron, silently revoking crontab
    # access -- including the nix-gc and store-optimise jobs. This case guards against
    # someone restoring those two watches from the published fix text.
    doesNotWatchCronAllow = assay.eq (builtins.any (r: builtins.match ".*cron\\.allow.*" r != null) rules) false;
    doesNotWatchCronDeny = assay.eq (builtins.any (r: builtins.match ".*cron\\.deny.*" r != null) rules) false;
    doesNotCreateCronAllow = assay.eq (builtins.any (r: builtins.match ".*cron\\.allow.*" r != null) tmpfiles) false;
  }
