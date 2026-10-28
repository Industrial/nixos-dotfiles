# V-268153 (CAT II) — NixOS must notify designated personnel if baseline configurations are
# changed in an unauthorized manner.
#
# Fix text installs AIDE with a `--sysconfdir=/etc` overlay, writes /etc/aide.conf, and adds a
# weekly cron job that mails the check results:
#
#   "00 0 * * 0\troot\taide -c /etc/aide.conf --check | /bin/mail -s "..." root@notareal.email"
#
# Three things about that. `root@notareal.email` is a placeholder that would silently discard
# every integrity report, which is why `security.stig.aideMailTo` has no default. `/bin/mail`
# does not exist on NixOS. And the overlay rebuilds AIDE from source to move its sysconfdir,
# which is a large closure change for a path that can be passed on the command line instead.
#
# There is also a real tension with this fleet's design, recorded in
# docs/security/stig-triage.md: comin's entire job is applying baseline changes from
# origin/main, so an integrity monitor that flags "unauthorized" change will flag every
# convergence. AIDE's database must be re-initialised after each activation for the signal to
# mean anything, which is what the systemd unit below does.
#
# `full` profile.
{
  config,
  lib,
  pkgs,
  ...
}: let
  mailTo = config.security.stig.aideMailTo;
in {
  assertions = [
    {
      assertion = mailTo != null;
      message = ''
        V-268153 mails AIDE integrity reports to designated personnel, and there is no safe
        default for that address — the fix text's own example is "root@notareal.email", which
        would discard every report.

          security.stig.aideMailTo = "security@example.com";

        or exclude the control:

          security.stig.exclude."V-268153" = "<how baseline change is detected here instead>";
      '';
    }
  ];

  environment.systemPackages = [pkgs.aide];

  environment.etc."aide.conf" = {
    mode = "0444";
    text = ''
      database_in=file:/var/lib/aide/aide.db
      database_out=file:/var/lib/aide/aide.db.new
      gzip_dbout=yes

      # Report only; the notification is the systemd unit's job.
      report_url=stdout

      # What "baseline configuration" means on NixOS: /etc is generated from the closure, and
      # the closure itself is immutable, so watching /etc and the bootloader is what detects
      # an out-of-band change.
      Full = p+i+n+u+g+s+m+c+md5+sha256
      Config = p+i+u+g+sha256

      /etc    Config
      /boot   Full
      !/etc/mtab
      !/etc/machine-id
      !/var/lib/aide
    '';
  };

  # optionalAttrs rather than mkIf, for the same reason as V-268108: mkIf wraps the unit in a
  # deferred node the colocated suite cannot read through, and the condition covers the whole
  # unit anyway.
  systemd.services.stig-aide-check = lib.optionalAttrs (mailTo != null) {
    description = "AIDE baseline integrity check (STIG V-268153)";
    startAt = "Sun 00:00";
    serviceConfig.Type = "oneshot";
    path = [pkgs.aide pkgs.system-sendmail];
    script = ''
      mkdir -p /var/lib/aide
      if [ ! -f /var/lib/aide/aide.db ]; then
        # First run, or the first after an activation changed the baseline. Initialise
        # instead of reporting every file as new.
        aide -c /etc/aide.conf --init
        mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        exit 0
      fi
      if ! aide -c /etc/aide.conf --check > /tmp/aide-report 2>&1; then
        sendmail -t <<EOF
      To: ${toString mailTo}
      Subject: AIDE integrity check findings on $(hostname)
      $(cat /tmp/aide-report)
      EOF
      fi
    '';
  };
}
