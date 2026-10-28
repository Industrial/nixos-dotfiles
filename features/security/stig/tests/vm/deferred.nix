# VM test specs for the controls that CANNOT be verified by evaluating configuration.
#
# These seven are the ones registered in `security.stig.deferredVerification`, where the
# baseline's honest position has been "believed correct, not proven". This file is what
# discharges that: each spec boots a machine and inspects the running system, turning an
# unverified claim into a verified one.
#
# Nothing here asserts a NixOS option. If a spec in this file could be written as an assay
# case, it belongs in a control's colocated suite instead.
{...}: [
  {
    id = "V-268115";
    description = "journald directory and logs are owned by root";
    modules = [./../../controls/V-268115.nix];
    script = ''
      # The fix text claims this is true "by design"; verify rather than take its word.
      machine.succeed("test -d /var/log/journal")
      machine.succeed("test \"$(stat -c %U /var/log/journal)\" = root")
      # Every journal file, not just the directory.
      machine.succeed(
          "find /var/log/journal -type f -name '*.journal' "
          "! -user root -print -quit | (! grep -q .)"
      )
    '';
  }

  {
    id = "V-268116";
    description = "journald directory and logs are group-owned by the journal group";
    modules = [./../../controls/V-268116.nix];
    script = ''
      # The published requirement and fix text both say the group is "systemd-journald".
      # No such group exists — that is the DAEMON's name. The group is "systemd-journal",
      # which is what systemd creates and what journald actually sets. Running the fix text's
      # `chown -R root:systemd-journald` verbatim fails with "invalid group".
      #
      # Assert the nonexistence first, so this test documents why it diverges from the
      # published text rather than looking like a transcription error of its own.
      machine.fail("getent group systemd-journald")
      machine.succeed("getent group systemd-journal")

      machine.succeed("test \"$(stat -c %G /var/log/journal)\" = systemd-journal")
      machine.succeed(
          "find /var/log/journal -type f -name '*.journal' "
          "! -group systemd-journal -print -quit | (! grep -q .)"
      )
    '';
  }

  {
    id = "V-268117";
    description = "journal directories are mode 2755 or less permissive";
    modules = [./../../controls/V-268117.nix];
    script = ''
      # "or less permissive" — so assert no directory grants group or other write, rather
      # than pinning the literal 2755 the fix text names.
      machine.succeed(
          "find /var/log/journal -type d -perm /0022 -print -quit | (! grep -q .)"
      )
      # The setgid bit is what keeps new journal files group-owned by systemd-journald.
      machine.succeed("test -g /var/log/journal")
    '';
  }

  {
    id = "V-268118";
    description = "journal files are mode 0640 or less permissive";
    modules = [./../../controls/V-268118.nix];
    script = ''
      # No journal file may be group-writable or readable/writable by other.
      machine.succeed(
          "find /var/log/journal -type f -name '*.journal' -perm /0027 "
          "-print -quit | (! grep -q .)"
      )
    '';
  }

  {
    id = "V-268121";
    description = "directories under /etc/audit are mode 0755 or less permissive";
    modules = [
      ./../../controls/V-268121.nix
      ./../../controls/V-268080.nix
      ./../../controls/V-268110.nix
    ];
    script = ''
      machine.succeed("test -d /etc/audit")
      # The files are store symlinks (proven at eval time by V-268120/122/123); the
      # containing directories are created by the etc activation script, which is why only a
      # booted machine can show their mode.
      machine.succeed(
          "find /etc/audit -type d -perm /0022 -print -quit | (! grep -q .)"
      )
      machine.succeed("test \"$(stat -c %U /etc/audit)\" = root")
    '';
  }

  {
    id = "V-268140";
    description = "every world-writable directory has the sticky bit set";
    modules = [./../../controls/V-268140.nix];
    script = ''
      # The fix text leaves "public directory" undefined, so enumerate instead of guessing:
      # any directory that is world-writable and NOT sticky is a finding. This is stronger
      # than a static list because it also catches a public directory introduced later.
      machine.succeed("test -k /tmp")
      machine.succeed("test -k /var/tmp")
      offenders = machine.succeed(
          "find / -xdev -type d -perm -0002 ! -perm -1000 -print 2>/dev/null || true"
      ).strip()
      assert offenders == "", f"world-writable directories without the sticky bit: {offenders}"
    '';
  }

  {
    id = "V-268175";
    description = "every interactive account's stored password hash is SHA-512";
    modules = [
      ./../../controls/V-268175.nix
      ./../../controls/V-268130.nix
    ];
    extraModules = [
      # A real account with a password set, so the assertion has something to inspect.
      # Without this the check would pass vacuously on a VM that has no interactive users.
      ({...}: {
        users.users.stigtest = {
          isNormalUser = true;
          initialPassword = "correct-horse-battery-staple";
        };
      })
    ];
    script = ''
      # The check reads field 2 of the $-delimited hash and requires 6 (SHA-512).
      machine.succeed("getent shadow stigtest | cut -d: -f2 | cut -d'$' -f2 | grep -qx 6")

      # And no interactive account may carry a weaker hash. Locked (!) and empty-password
      # accounts are not interactive and are skipped, which is what the control means by
      # "interactive user accounts".
      weak = machine.succeed(
          "awk -F: '$2 ~ /^\\$/ && $2 !~ /^\\$6\\$/ { print $1 }' /etc/shadow || true"
      ).strip()
      assert weak == "", f"accounts not using SHA-512: {weak}"
    '';
  }
]
