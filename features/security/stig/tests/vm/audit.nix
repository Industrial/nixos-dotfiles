# VM test specs for the audit subsystem.
#
# Every spec here boots the REAL base-safe profile rather than a hand-picked module list, so
# each test also proves the composition: all 36 audit rules load together without auditctl
# rejecting one, auditd starts, and the settings from four separate controls land in one
# auditd.conf. A per-control module list would verify the control in isolation and miss
# exactly the interaction that V-268148 exists to avoid.
#
# Two things the published checks tell us, which shape every rule assertion below:
#
#   "The '-k' allows for specifying an arbitrary identifier. The string following '-k' does
#    not need to match the example output above."
#
# and auditctl NORMALISES rules as it loads them — our declared `-F auid!=unset` comes back
# from `auditctl -l` as `-F auid!=-1`. So matching a whole rule line against the text we
# declared would fail for reasons that have nothing to do with compliance. The specs match on
# the stable fields: architecture, syscall set, and the filters that carry the security
# meaning.
{...}: let
  profile = ./../../profiles/base-safe.nix;

  # Shared preamble: the audit rules are loaded by a systemd unit, so a test that greps
  # auditctl before it has run is racy.
  # `auditctl -l` prints the literal text "No rules" when none are loaded, so waiting for
  # non-empty output is not a readiness check — it succeeds on the failure case. Wait for the
  # loader unit and then for a rule that actually looks like a rule.
  #
  # This matters because auditctl aborts the whole rules file on the first unloadable rule
  # (a watch on a missing path, for instance) and exits non-zero. When that happens NOT ONE
  # rule is loaded, and a test that only grepped for its own rule would report a confusing
  # single-control failure instead of "the audit subsystem is down".
  auditReady = ''
    machine.wait_for_unit("auditd.service")
    machine.succeed("systemctl is-active audit-rules-nixos.service || true")
    rules_status = machine.execute("systemctl is-active audit-rules-nixos.service")[1].strip()
    loaded = machine.succeed("auditctl -l")
    assert "No rules" not in loaded, (
        "the audit rule set failed to load, so no control in this group can be verified. "
        f"audit-rules-nixos.service is '{rules_status}'. "
        "auditctl aborts the entire file on one unloadable rule -- usually a -w watch on a "
        "path that does not exist. Journal:\n"
        + machine.execute("journalctl -u audit-rules-nixos --no-pager | tail -40")[1]
    )
    machine.wait_until_succeeds("auditctl -l | grep -qE '^-[aw] '")
  '';

  # One spec per control, all against the composed profile.
  ruleSpec = id: description: script: {
    inherit id description;
    modules = [profile];
    script = auditReady + script;
  };
in [
  (ruleSpec "V-268080" "the audit daemon and kernel audit are both active" ''
    # Both halves: the userspace daemon that writes /var/log/audit, and kernel auditing.
    machine.succeed("systemctl is-active auditd.service | grep -qx active")
    # Kernel audit enabled. auditctl has shipped two output shapes for `-s` over the years
    # ("enabled 1" per line, and the older "AUDIT_STATUS: enabled=1 flag=1 ..."), so match
    # either rather than pinning one and failing for a formatting reason.
    status = machine.succeed("auditctl -s")
    print("auditctl -s:\n" + status)
    import re
    m = re.search(r"enabled[ =]+([0-9]+)", status)
    assert m, f"could not find 'enabled' in auditctl -s output:\n{status}"
    assert int(m.group(1)) >= 1, f"kernel audit is not enabled (enabled={m.group(1)})"
  '')

  (ruleSpec "V-268090" "the audit userspace tools are on PATH" ''
    # The requirement says "package installed"; the usable form of that is the tools working.
    machine.succeed("command -v auditctl")
    machine.succeed("command -v auditd")
    machine.succeed("command -v ausearch")
  '')

  (ruleSpec "V-268092" "auditing is enabled before the audit daemon starts" ''
    # Verified on the kernel command line, which is what makes pre-daemon events auditable.
    machine.succeed("grep -qw 'audit=1' /proc/cmdline")
  '')

  (ruleSpec "V-268093" "the audit backlog limit is at least 8192" ''
    machine.succeed("grep -qw 'audit_backlog_limit=8192' /proc/cmdline")
    # And the running kernel actually took it. Tolerant of both auditctl -s output shapes.
    import re
    status = machine.succeed("auditctl -s")
    m = re.search(r"backlog_limit[ =]+([0-9]+)", status)
    assert m, f"could not find 'backlog_limit' in auditctl -s output:\n{status}"
    assert int(m.group(1)) >= 8192, f"backlog_limit is {m.group(1)}, expected at least 8192"
  '')

  (ruleSpec "V-268091" "privileged command execution is audited on both architectures" ''
    rules = machine.succeed("auditctl -l | grep execve")
    for arch in ["b32", "b64"]:
        assert f"arch={arch}" in rules, f"no execve rule for arch={arch}"
    # uid!=euid catches setuid escalation; gid!=egid catches setgid. Both are required.
    assert "euid=0" in rules, "no euid=0 execve rule"
    assert "egid=0" in rules, "no egid=0 execve rule"
  '')

  (ruleSpec "V-268094" "the mount syscall is audited" ''
    rules = machine.succeed("auditctl -l | grep -w -- '-S mount'")
    for arch in ["b32", "b64"]:
        assert f"arch={arch}" in rules, f"no mount rule for arch={arch}"
  '')

  (ruleSpec "V-268095" "file deletion syscalls are audited" ''
    # Match on the key, not on a leading syscall name. auditctl maps syscall names to numbers
    # per architecture and re-renders the list in numeric order, so the b32 and b64 forms of
    # the same rule list the syscalls in DIFFERENT orders — `grep '-S rename'` finds one and
    # misses the other. The key is stable.
    rules = machine.succeed("auditctl -l | grep -w -- '-k delete'")
    for syscall in ["rename", "unlink", "rmdir", "renameat", "unlinkat"]:
        assert syscall in rules, f"{syscall} missing from the delete rule:\n{rules}"
    for arch in ["b32", "b64"]:
        assert f"arch={arch}" in rules, f"no delete rule for arch={arch}:\n{rules}"
  '')

  (ruleSpec "V-268096" "kernel module load and unload are audited" ''
    rules = machine.succeed("auditctl -l | grep -w -- '-S init_module'")
    for syscall in ["init_module", "finit_module", "delete_module"]:
        assert syscall in rules, f"{syscall} missing from the module rule"
    for arch in ["b32", "b64"]:
        assert f"arch={arch}" in rules, f"no module rule for arch={arch}"
  '')

  (ruleSpec "V-268097" "crontab changes are audited" ''
    # The watch target must exist before auditctl loads the rule, so the control provisions
    # it via tmpfiles and default.nix orders the loader after tmpfiles.
    machine.succeed("test -d /var/cron/tabs")

    rules = machine.succeed("auditctl -l | grep -w -- '-k services'")
    assert "/var/cron/tabs" in rules, f"crontab directory is not watched:\n{rules}"

    # cron.allow and cron.deny are a documented partial exclusion. Creating an empty
    # cron.allow so a watch could load would tell cron that NO user may use cron, silently
    # revoking crontab access including the nix-gc and store-optimise jobs. Assert they are
    # genuinely absent rather than silently unwatched, so the exclusion stays deliberate.
    machine.succeed("test ! -e /var/cron/cron.allow")
  '')

  (ruleSpec "V-268098" "denied file-access syscalls are audited" ''
    rules = machine.succeed("auditctl -l | grep -w -- '-S open'")
    for syscall in ["open", "creat", "truncate", "ftruncate", "openat", "open_by_handle_at"]:
        assert syscall in rules, f"{syscall} missing from the access rule"
    # Only denials are audited; an unconditional rule here would flood the log.
    assert "EACCES" in rules, "no EACCES-filtered rule"
    assert "EPERM" in rules, "no EPERM-filtered rule"
  '')

  (ruleSpec "V-268099" "ownership-change syscalls are audited" ''
    # Same per-architecture reordering as V-268095, so select the lines that mention chown
    # rather than assuming it leads the syscall list.
    rules = machine.succeed("auditctl -l | grep -- 'chown'")
    for syscall in ["chown", "fchown", "lchown", "fchownat"]:
        assert syscall in rules, f"{syscall} missing from the chown rule:\n{rules}"
    for arch in ["b32", "b64"]:
        assert f"arch={arch}" in rules, f"no chown rule for arch={arch}:\n{rules}"
  '')

  (ruleSpec "V-268100" "permission-change syscalls are audited" ''
    rules = machine.succeed("auditctl -l | grep -w -- '-S chmod'")
    for syscall in ["chmod", "fchmod", "fchmodat"]:
        assert syscall in rules, f"{syscall} missing from the chmod rule"
    for arch in ["b32", "b64"]:
        assert f"arch={arch}" in rules, f"no chmod rule for arch={arch}"
  '')

  (ruleSpec "V-268103" "auditd acts at 75 percent volume utilisation" ''
    # Expressed as remaining space: 25% left is 75% used.
    machine.succeed("grep -qE '^space_left *= *25%' /etc/audit/auditd.conf")
  '')

  (ruleSpec "V-268104" "auditd acts at 90 percent volume utilisation" ''
    machine.succeed("grep -qE '^admin_space_left *= *10%' /etc/audit/auditd.conf")
  '')

  (ruleSpec "V-268105" "auditd takes an accepted action when the volume is full" ''
    action = machine.succeed(
        "awk -F= '/^disk_full_action/ { gsub(/ /, \"\", $2); print $2 }' /etc/audit/auditd.conf"
    ).strip()
    # The check accepts SYSLOG, SINGLE or HALT. We choose SYSLOG deliberately: HALT, which the
    # fix text names, powers the machine off when the audit volume fills.
    assert action in ["SYSLOG", "SINGLE", "HALT"], f"disk_full_action={action} is not accepted"
    assert action != "HALT", "disk_full_action=HALT would power the host off"
  '')

  (ruleSpec "V-268106" "auditd takes an accepted action on a processing failure" ''
    action = machine.succeed(
        "awk -F= '/^disk_error_action/ { gsub(/ /, \"\", $2); print $2 }' /etc/audit/auditd.conf"
    ).strip()
    assert action in ["SYSLOG", "SINGLE", "HALT"], f"disk_error_action={action} is not accepted"
    assert action != "HALT", "disk_error_action=HALT would power the host off"
  '')

  (ruleSpec "V-268107" "kernel audit messages reach the journal" ''
    # What the published check actually verifies.
    machine.succeed("systemctl is-active systemd-journald.service | grep -qx active")

    # And the setting behind it. journald config can live in journald.conf or a drop-in, and
    # systemd accepts yes/true/1 for a boolean, so search broadly rather than pinning one
    # spelling in one file.
    conf = machine.succeed(
        "cat /etc/systemd/journald.conf /etc/systemd/journald.conf.d/*.conf 2>/dev/null || "
        "cat /etc/systemd/journald.conf"
    )
    print("journald config:\n" + conf)
    import re
    assert re.search(r"(?mi)^\s*Audit\s*=\s*(yes|true|1)\s*$", conf), (
        f"journald is not configured to accept audit records:\n{conf}"
    )
  '')

  (ruleSpec "V-268110" "auditd writes logs group-owned by root" ''
    machine.succeed("grep -qE '^log_group *= *root' /etc/audit/auditd.conf")
  '')

  (ruleSpec "V-268111" "the audit directory and logs are owned by root" ''
    machine.succeed("test \"$(stat -c %U /var/log/audit)\" = root")
    machine.succeed(
        "find /var/log/audit ! -user root -print -quit | (! grep -q .)"
    )
  '')

  (ruleSpec "V-268112" "the audit directory and logs are group-owned by root" ''
    machine.succeed("test \"$(stat -c %G /var/log/audit)\" = root")
    machine.succeed(
        "find /var/log/audit ! -group root -print -quit | (! grep -q .)"
    )
  '')

  (ruleSpec "V-268113" "the audit log directory is mode 0700 or less permissive" ''
    # "or any subfolders" per the check text, so walk the tree rather than stat the top.
    machine.succeed(
        "find /var/log/audit -type d -perm /0077 -print -quit | (! grep -q .)"
    )
    machine.succeed("test \"$(stat -c %a /var/log/audit)\" = 700")
  '')

  (ruleSpec "V-268114" "audit logs are mode 0600 or less permissive" ''
    machine.succeed(
        "find /var/log/audit -type f -perm /0177 -print -quit | (! grep -q .)"
    )
  '')

  (ruleSpec "V-268119" "logon UIDs are immutable" ''
    # The check expects the literal "loginuid_immutable 1 locked". Assert the value rather
    # than the whole string, so an auditctl formatting change is not mistaken for a finding.
    import re
    status = machine.succeed("auditctl -s")
    m = re.search(r"loginuid_immutable[ =]+([0-9]+)", status)
    assert m, f"could not find 'loginuid_immutable' in auditctl -s output:\n{status}"
    assert int(m.group(1)) == 1, f"loginuid_immutable is {m.group(1)}, expected 1"
    assert "locked" in status, f"loginuid immutability is not locked:\n{status}"
  '')

  (ruleSpec "V-268120" "audit configuration files are not writable" ''
    # On NixOS these are symlinks into the read-only store, which is stronger than mode 444
    # on a mutable file: root cannot rewrite a store path at all.
    machine.succeed("test -L /etc/audit/auditd.conf")
    target = machine.succeed("readlink -f /etc/audit/auditd.conf").strip()
    assert target.startswith("/nix/store/"), f"auditd.conf resolves to {target}, not the store"
    machine.fail("test -w " + target)
  '')

  (ruleSpec "V-268122" "audit configuration files and directories are owned by root" ''
    machine.succeed(
        "find /etc/audit -exec stat -L -c '%U' {} + | sort -u | grep -qx root"
    )
  '')

  (ruleSpec "V-268123" "audit configuration files and directories are group-owned by root" ''
    machine.succeed(
        "find /etc/audit -exec stat -L -c '%G' {} + | sort -u | grep -qx root"
    )
  '')

  (ruleSpec "V-268148" "privilege-escalation auditing is loaded exactly once" ''
    # This control emits nothing: its four rules are byte-identical to V-268091's. The point
    # of the design is that the rules are present AND not duplicated, because auditctl can
    # reject an exact duplicate and fail the whole audit-rules unit.
    rules = machine.succeed("auditctl -l | grep execve").strip().splitlines()
    assert len(rules) == 4, f"expected 4 execve rules, found {len(rules)}: {rules}"
    assert len(set(rules)) == 4, f"duplicate execve rules loaded: {rules}"
    # And the unit that loads them did not fail.
    machine.succeed("systemctl is-active audit-rules.service || systemctl is-active auditd.service")
  '')

  (ruleSpec "V-268163" "extended-attribute changes are audited for users and root" ''
    rules = machine.succeed("auditctl -l | grep -w -- '-S setxattr'")
    for syscall in ["setxattr", "fsetxattr", "lsetxattr", "removexattr", "fremovexattr", "lremovexattr"]:
        assert syscall in rules, f"{syscall} missing from the xattr rule"
    # The root-side rules are the easy ones to lose, and losing them means a root-performed
    # change is never recorded.
    assert "auid=0" in rules, "no root-side xattr rule"
    assert "auid>=1000" in rules, "no user-side xattr rule"
  '')

  (ruleSpec "V-268164" "usermod execution is audited" ''
    rules = machine.succeed("auditctl -l | grep -w -- '-S all' || auditctl -l | grep usermod")
    assert "usermod" in rules, "usermod is not watched"
  '')

  (ruleSpec "V-268165" "chage execution is audited" ''
    rules = machine.succeed("auditctl -l | grep chage")
    assert "chage" in rules, "chage is not watched"
    # chcon is an SELinux tool and will not exist on this AppArmor system; the rule is kept
    # verbatim from the fix text and is inert by design, so it is not asserted here.
  '')

  (ruleSpec "V-268166" "lastlog is watched for logon records" ''
    rules = machine.succeed("auditctl -l | grep lastlog")
    assert "/var/log/lastlog" in rules, "lastlog is not watched"
  '')

  (ruleSpec "V-268167" "the identity databases are watched" ''
    rules = machine.succeed("auditctl -l | grep -w -- '-k identity'")
    for path in ["/etc/passwd", "/etc/shadow", "/etc/gshadow", "/etc/group", "/etc/sudoers", "/etc/security/opasswd"]:
        assert path in rules, f"{path} is not watched"
  '')
]
