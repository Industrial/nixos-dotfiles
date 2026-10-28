# VM test specs for kernel, network, time, supply chain and session controls.
#
# Every spec boots the real base-safe profile. Several of these controls are only meaningful
# at runtime: a sysctl declared in Nix proves nothing about the running kernel, and the
# STIG's checks read the kernel, not the configuration.
{...}: let
  profile = ./../../profiles/base-safe.nix;

  spec = id: description: script: {
    inherit id description;
    modules = [profile];
    inherit script;
  };

  # Read a sysctl the way the checks do.
  sysctlIs = key: want: ''
    value = machine.succeed("sysctl -n ${key}").strip()
    assert value == "${want}", f"${key} is {value}, expected ${want}"
  '';
in [
  (spec "V-268078" "the built-in firewall is active" ''
    # The check greps the nixos-fw chain and the panic helpers, both of which only exist on a
    # running system with the firewall enabled.
    machine.wait_for_unit("firewall.service")
    machine.succeed("iptables -L | grep -q nixos-fw-log-refuse")
    machine.succeed("command -v firewall-panic")
    machine.succeed("command -v firewall-panic-off")
  '')

  (spec "V-268141" "IPv4 TCP syncookies are enabled" (sysctlIs "net.ipv4.tcp_syncookies" "1"))

  (spec "V-268160" "kernel pointers are restricted" ''
    ${sysctlIs "kernel.kptr_restrict" "1"}
    # The check is an EQUALITY test against 1, so the stricter value 2 is a FINDING. This
    # assertion exists to fail if someone "improves" it. See ADR-0003.
    assert value != "2", "kptr_restrict=2 is stricter but non-compliant: the check tests for 1"
  '')

  (spec "V-268161" "address space layout randomization is fully enabled" ''
    ${sysctlIs "kernel.randomize_va_space" "2"}
  '')

  (spec "V-268131" "no telnet client is present" ''
    # The check is `whereis telnet` returning no path.
    machine.fail("command -v telnet")
    # And the eval-time assertion in the control must be what keeps it that way.
    machine.fail("test -e /run/current-system/sw/bin/telnet")
  '')

  (spec "V-268151" "time synchronization is enabled" ''
    # The unit is enabled; a sandboxed VM has no reachable time source, so this asserts the
    # service is running and not that the clock is accurate. See harness.nix for why the test
    # instrumentation's timesyncd override had to be reversed.
    machine.succeed("systemctl is-enabled systemd-timesyncd.service")
    machine.wait_for_unit("systemd-timesyncd.service")
  '')

  (spec "V-268150" "the clock is polled at least once a minute" ''
    conf = machine.succeed(
        "cat /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf.d/*.conf 2>/dev/null || "
        "cat /etc/systemd/timesyncd.conf"
    )
    print("timesyncd config:\n" + conf)
    import re
    m = re.search(r"(?mi)^\s*PollIntervalMaxSec\s*=\s*(\d+)", conf)
    assert m, f"PollIntervalMaxSec is not set:\n{conf}"
    # The check is an inequality: greater than 60 is a finding, so 60 is a ceiling.
    assert int(m.group(1)) <= 60, f"PollIntervalMaxSec is {m.group(1)}, must be <= 60"
  '')

  (spec "V-268154" "substituted store paths must be signed" ''
    # nix.conf is the authority the daemon reads.
    conf = machine.succeed("cat /etc/nix/nix.conf")
    import re
    m = re.search(r"(?mi)^\s*require-sigs\s*=\s*(\S+)", conf)
    # Absent means the built-in default, which is true; present must not be false.
    if m:
        assert m.group(1).lower() in ["true", "1"], f"require-sigs is {m.group(1)}"
    machine.succeed("nix config show require-sigs | grep -qx true")
  '')

  (spec "V-268156" "sudo requires a password" ''
    sudoers = machine.succeed("cat /etc/sudoers")
    print("sudoers:\n" + sudoers)
    # No NOPASSWD for the wheel group. A NOPASSWD rule anywhere for wheel defeats the control.
    import re
    offenders = [
        line for line in sudoers.splitlines()
        if "NOPASSWD" in line and not line.strip().startswith("#") and "%wheel" in line
    ]
    assert not offenders, f"wheel has passwordless sudo: {offenders}"
  '')

  (spec "V-268181" "new files default to owner-only" ''
    # login.defs is what the check reads.
    machine.succeed("grep -qE '^\\s*UMASK\\s+077' /etc/login.defs")
  '')

  (spec "V-268085" "concurrent sessions are capped at 10" ''
    # The check greps the limits.conf that pam_limits is pointed at, which on NixOS is a
    # store path referenced from /etc/pam.d/login rather than /etc/security/limits.conf.
    login = machine.succeed("cat /etc/pam.d/login")
    import re
    m = re.search(r"conf=(\S+)", login)
    assert m, f"pam_limits is not configured with a conf= path:\n{login}"
    limits = machine.succeed(f"cat {m.group(1)}")
    print("limits.conf:\n" + limits)
    assert re.search(r"(?m)^\*\s+hard\s+maxlogins\s+10\s*$", limits), (
        f"maxlogins is not a hard limit of 10:\n{limits}"
    )
  '')

  (spec "V-268087" "a user-initiated session lock is available" ''
    # The check is literally `which vlock`.
    machine.succeed("command -v vlock")
  '')

  (spec "V-268173" "AppArmor is loaded and active" ''
    # The check requires the unit enabled AND active, not merely configured.
    machine.wait_for_unit("apparmor.service")
    machine.succeed("systemctl is-active apparmor.service | grep -qx active")
    # And the LSM is actually present in the kernel, which the unit alone does not prove.
    machine.succeed("grep -qw apparmor /sys/kernel/security/lsm")
  '')
]
