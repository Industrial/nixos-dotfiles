# STIG base-safe profile — the controls that cost nothing interactively.
#
# Imported by profiles/base.nix, so every host carries it. Membership is decided by
# docs/security/stig-triage.md; a control belongs here only if it changes no login, lock,
# device, radio or password-entry behaviour a user would notice.
#
# Composition is by import. There is no enable flag gating the controls — the profile either
# is imported or is not, like every other feature in this repo. `security.stig.*` below is
# metadata that lib/report.nix reads.
#
# Growing in groups, each gated on `assay run features/security/stig` plus a four-host eval.
# Group 1 (landed): network, kernel, time, AppArmor, telnet absence.
{...}: {
  imports = [
    ../default.nix

    # Group 1 — network, kernel, time, AppArmor, telnet absence.
    ../controls/V-268078.nix # built-in firewall enabled
    ../controls/V-268131.nix # telnet absent (CAT I, assertion)
    ../controls/V-268141.nix # IPv4 TCP syncookies
    ../controls/V-268151.nix # time synchronization enabled
    ../controls/V-268173.nix # AppArmor enabled

    # Group 2a — audit daemon and syscall/watch rules.
    ../controls/V-268080.nix # auditd + kernel audit enabled
    ../controls/V-268091.nix # privileged command usage
    ../controls/V-268094.nix # mount syscall
    ../controls/V-268095.nix # rename/unlink/rmdir/renameat/unlinkat
    ../controls/V-268096.nix # init_module/finit_module/delete_module
    ../controls/V-268097.nix # cron configuration changes
    ../controls/V-268098.nix # denied open/creat/truncate family
    ../controls/V-268099.nix # chown family
    ../controls/V-268100.nix # chmod family
    ../controls/V-268119.nix # loginuid immutable
    ../controls/V-268148.nix # covered by V-268080 + V-268091 (emits nothing)
    ../controls/V-268163.nix # xattr modification, users and root
    ../controls/V-268164.nix # usermod execution
    ../controls/V-268165.nix # chage / chcon execution
    ../controls/V-268166.nix # lastlog watch
    ../controls/V-268167.nix # identity database watches

    # Group 2b — audit package/kernel consequences, log ownership and modes.
    ../controls/V-268090.nix # audit package (via V-268080)
    ../controls/V-268092.nix # audit=1 kernel param (via V-268080)
    ../controls/V-268093.nix # audit_backlog_limit raised to 8192
    ../controls/V-268110.nix # auditd log_group = root
    ../controls/V-268111.nix # audit dir+log owned by root (via V-268113/114)
    ../controls/V-268112.nix # audit dir+log group root (via V-268113/114)
    ../controls/V-268113.nix # audit log dir 0700 root:root (tmpfiles)
    ../controls/V-268114.nix # audit log file 0600 root:root (tmpfiles)
    ../controls/V-268115.nix # journald ownership (deferred)
    ../controls/V-268116.nix # journald group ownership (deferred)
    ../controls/V-268117.nix # journal dir mode (deferred)
    ../controls/V-268118.nix # journal file mode (deferred)
    ../controls/V-268120.nix # audit config files immutable (store symlinks)
    ../controls/V-268121.nix # /etc/audit dir mode (deferred)
    ../controls/V-268122.nix # /etc/audit owned by root
    ../controls/V-268123.nix # /etc/audit group-owned by root
    ../controls/V-268140.nix # sticky bit on public dirs (deferred)

    # Group 3 — SSH and transport crypto.
    ../controls/V-268088.nix # sshd LogLevel VERBOSE
    ../controls/V-268089.nix # approved ciphers (CAT I)
    ../controls/V-268137.nix # no direct root login over SSH
    ../controls/V-268142.nix # ClientAliveInterval 600
    ../controls/V-268143.nix # ClientAliveCountMax 1
    ../controls/V-268157.nix # approved MACs (CAT I)
    ../controls/V-268159.nix # encrypted transport enabled (CAT I)
    ../controls/V-268176.nix # SSH authenticates through PAM (CAT I)

    # Group 4 — auditd storage actions, sysctls, supply chain, session and permission defaults.
    ../controls/V-268085.nix # maxlogins 10 (CAT III)
    ../controls/V-268087.nix # vlock available for console session lock
    ../controls/V-268103.nix # act at 75% audit volume
    ../controls/V-268104.nix # act at 90% audit volume
    ../controls/V-268105.nix # disk_full_action SYSLOG (not HALT)
    ../controls/V-268106.nix # disk_error_action SYSLOG (not HALT)
    ../controls/V-268107.nix # kernel audit into the journal
    ../controls/V-268150.nix # timesyncd PollIntervalMaxSec 60
    ../controls/V-268154.nix # require-sigs (CAT I)
    ../controls/V-268156.nix # sudo requires a password
    ../controls/V-268160.nix # kernel.kptr_restrict = 1
    ../controls/V-268161.nix # kernel.randomize_va_space = 2
    ../controls/V-268181.nix # UMASK 077

    # Group 5 — password complexity and hashing. The six pwquality.conf settings share one
    # file via security.stig.pwquality; V-268170, which wires pam_pwquality into PAM, is in
    # the full profile because a bad PAM line breaks password changes.
    ../controls/V-268126.nix # ucredit=-1 (uppercase required)
    ../controls/V-268127.nix # lcredit=-1 (lowercase required)
    ../controls/V-268128.nix # dcredit=-1 (digit required)
    ../controls/V-268129.nix # difok=8 (50% of characters must change)
    ../controls/V-268130.nix # ENCRYPT_METHOD SHA512 (CAT I)
    ../controls/V-268145.nix # ocredit=-1 (special character required)
    ../controls/V-268169.nix # dictcheck=1 (no dictionary words)
    ../controls/V-268171.nix # FAIL_DELAY 4
    ../controls/V-268175.nix # stored hashes are SHA-512 (deferred)
  ];

  security.stig = {
    enable = true;
    profile = "base-safe";

    # Controls whose requirement cannot be observed by evaluating the configuration — runtime
    # state only. Each is proven instead by a VM test in ../tests/vm/deferred.nix, all seven
    # of which pass on a booted machine; `moon run stig-vm-test` is their gate, not
    # `moon run test`.
    #
    # The obligation runs both ways: each control's colocated suite asserts its presence here,
    # and tests/vm/deferred.assay.nix asserts every entry here has a VM spec. Neither a
    # silently-unregistered control nor an unimplemented registration can survive the gate.
    deferredVerification = {
      "V-268115" = "journald log ownership under /var/log/journal is runtime state set by systemd-journald; only a booted machine can show it.";
      "V-268116" = "journald log group ownership is runtime state set by systemd-journald; only a booted machine can show it.";
      "V-268117" = "journal directory mode 2755 is set by systemd-journald at runtime and is not visible in the evaluated configuration.";
      "V-268118" = "journal file mode 0640 is set by systemd-journald at runtime and is not visible in the evaluated configuration.";
      "V-268121" = "directories under /etc/audit are created by the etc activation script at boot; only the files inside them are evaluable.";
      "V-268140" = "the fix text leaves 'public directory' undefined, so the VM test enumerates world-writable directories on a booted machine and asserts the sticky bit on each.";
      "V-268175" = "concerns the hashes already stored in /etc/shadow, which no configuration can assert; V-268130 only governs new passwords. The VM test reads /etc/shadow and asserts field 2 is 6 for every interactive account.";
    };
  };
}
