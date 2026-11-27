# VM test specs for the 15 controls muninn's test-host profile adds to base-safe (ADR-0008).
#
# Every spec boots the real profiles/test-host.nix, so each test also proves the composition
# the host actually carries: base-safe's 68 controls plus these 15 evaluate together, boot,
# and leave the setting each check reads in effect. That is the gap ADR-0008 recorded when the
# profile went onto a real machine: until now these 15 had only been read as attrsets by
# their suites, and two of them (V-268083, V-268174) did not evaluate on a real host at all.
#
# Each script is the control's own check content, run on the booted machine. Where a check
# only greps a file, the script also asks the running system (sshd, logind, sudo, the nix
# daemon, useradd), because a line in a file is not the same thing as a setting in effect:
# V-268155's line was in /etc/sudoers on muninn and overridden by a later one.
#
# Three checks cannot be run as published, and the scripts say so where it happens:
#
#   V-268152, V-268172  grep /etc/nixos, which a flake-deployed host does not have. The
#                       scripts read what that source would have produced instead.
#   V-268086            also requires an xautolock user unit. xautolock is X11-only and the
#                       control deliberately does not install it; see the spec.
#
# And writing them found two things the suites could not, both recorded in the specs:
#
#   V-268132  PASS_MIN_DAYS is in login.defs and the check passes, but shadow 4.20 no longer
#             implements a minimum password age, so no account is held to it.
#   V-268086  the dconf lock on idle-delay is declared without its leading slash and is
#             not in effect. The check does not ask for the lock; the control's module does.
{lib, ...}: let
  profile = ./../../profiles/test-host.nix;

  spec = id: description: script: {
    inherit id description script;
    modules = [profile];
  };

  specWith = extraModules: id: description: script:
    (spec id description script) // {inherit extraModules;};

  # The banner an assessor compares against is the one printed in each control's CHECK text,
  # so the expected paragraphs are parsed out of the vendored benchmark rather than taken
  # from ../../lib/dow-banner.nix. That keeps the test independent of the module under test:
  # both would have to drift the same way for a wrong banner to pass.
  benchmark = builtins.fromJSON (builtins.readFile ./../../data/Anduril_NixOS_STIG-V1R3.controls.json);

  trim = s: let
    m = builtins.match "[[:space:]]*(.*[^[:space:]])[[:space:]]*" s;
  in
    if m == null
    then ""
    else builtins.head m;

  # The check text is: one sentence of instruction, the command lines (`$ ...`), the banner,
  # and a closing "If ..." sentence. What is left after dropping the other three is the banner.
  bannerInCheck = id: let
    lines = builtins.filter (l: l != "") (map trim (lib.splitString "\n" benchmark.controls.${id}.checkContent));
  in
    builtins.filter (l: !(lib.hasPrefix "$" l) && !(lib.hasPrefix "If " l)) (builtins.tail lines);

  # JSON string syntax is valid Python string syntax for this text (plain ASCII, no escapes
  # beyond the quote).
  expectBanner = id: ''
    expected = ${builtins.toJSON (bannerInCheck id)}
    assert len(expected) == 7, f"expected the seven paragraphs of the notice, parsed {len(expected)}"
  '';

  # Compare paragraph by paragraph, ignoring blank lines and indentation: the check prints the
  # banner indented by one space and the three consumers space paragraphs differently.
  sameBanner = what: ''
    shown = [line.strip() for line in ${what}.splitlines() if line.strip()]
    assert shown == expected, f"banner does not match the check text.\nshown: {shown}\nexpected: {expected}"
  '';

  # GDM as the greeter, which is what muninn runs and the only place the graphical controls
  # have a consumer.
  withGdm = {
    services.displayManager.gdm.enable = true;
    virtualisation.memorySize = 2048;
  };

  # An interactive account, so "nobody is logged in" and "a new account inherits the policy"
  # are statements about a machine that has users.
  withUser = {
    users.users.stigtest = {
      isNormalUser = true;
      initialPassword = "correct-horse-battery-staple";
    };
  };

  # Create an account the way an administrator would and read back what it was given.
  # login.defs and /etc/default/useradd are defaults for NEW accounts, so a freshly created
  # one is the only place their effect can be observed.
  newAccountAging = ''
    machine.succeed("useradd --create-home stigprobe")
    fields = machine.succeed("getent shadow stigprobe").strip().split(":")
    print("shadow entry of a new account:", fields)
  '';
in [
  (spec "V-268082" "the consent banner is shown before a console logon" ''
    ${expectBanner "V-268082"}
    # The check, verbatim.
    issue = machine.succeed("tail -n+3 /etc/issue")
    print("/etc/issue from line 3:\n" + issue)
    ${sameBanner "issue"}

    # And agetty really prints it: the last sentence of the notice is on the console, above
    # the login prompt. (The whole notice is longer than a 25-line console, so the first
    # paragraphs have scrolled off by the time the prompt is drawn.)
    machine.wait_until_tty_matches("1", "See User Agreement for details")
    machine.wait_until_tty_matches("1", "login:")
  '')

  (spec "V-268083" "the consent banner is sent before an SSH logon" ''
    ${expectBanner "V-268083"}
    machine.wait_for_unit("sshd.service")
    machine.wait_for_open_port(22)

    # The check: Banner is configured, and the file it names holds the notice.
    machine.succeed("grep -q '^Banner ' /etc/ssh/sshd_config")
    import re
    conf = machine.succeed("sshd -T")
    m = re.search(r"(?mi)^banner\s+(\S+)", conf)
    assert m and m.group(1) != "none", f"sshd reports no effective banner:\n{conf}"
    banner_file = machine.succeed(f"cat {m.group(1)}")
    ${sameBanner "banner_file"}

    # sshd sends it BEFORE authentication: a client that cannot log in still receives it.
    # BatchMode makes the attempt fail instead of prompting.
    status, out = machine.execute(
        "ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
        "stig-nobody@127.0.0.1 true 2>&1"
    )
    print("unauthenticated ssh client saw:\n" + out)
    assert status != 0, "an account that does not exist was let in"
    received = [line.strip() for line in out.splitlines() if line.strip()]
    missing = [p for p in expected if p not in received]
    assert not missing, f"sshd did not send these paragraphs before authentication: {missing}"
  '')

  (specWith [withGdm] "V-268084" "the consent banner is shown on the graphical greeter" ''
    ${expectBanner "V-268084"}
    # The check, verbatim: GDM's own dconf profile, which is what the greeter reads.
    raw = machine.succeed(
        "DCONF_PROFILE=gdm dconf read /org/gnome/login-screen/banner-message-text"
    ).strip()
    assert raw, "the gdm dconf profile has no banner-message-text"
    # dconf prints a GVariant string: quoted, with newlines escaped.
    import ast
    text = ast.literal_eval(raw)
    ${sameBanner "text"}

    # The text is only drawn when the greeter is also told to show a banner.
    enabled = machine.succeed(
        "DCONF_PROFILE=gdm dconf read /org/gnome/login-screen/banner-message-enable"
    ).strip()
    assert enabled == "true", f"banner-message-enable is {enabled!r}, so the text is not shown"
  '')

  (spec "V-268086" "the session locks after ten minutes of inactivity" ''
    # Leg 1 of the check: `gsettings get org.gnome.desktop.session idle-delay` -> uint32 600.
    # Read through dconf, the store gsettings reads, so the test does not need a GNOME schema
    # installed. Zero (never) and anything above 600 are findings.
    idle = machine.succeed("dconf read /org/gnome/desktop/session/idle-delay").strip()
    assert idle.startswith("uint32 "), f"idle-delay is not set in the user dconf profile: {idle!r}"
    seconds = int(idle.split()[1])
    assert 0 < seconds <= 600, f"idle-delay is {seconds}; must be between 1 and 600"
    # The check does not ask whether the key is LOCKED against a user's own setting, and this
    # does not assert it. For the record, it is not: the control declares the lock without
    # the leading slash dconf requires, so `dconf list-locks` comes back empty. Printed, so
    # the log of this test shows the state either way.
    print("dconf locks under /org/gnome/desktop/session/:", repr(machine.succeed(
        "dconf list-locks /org/gnome/desktop/session/"
    )))

    # Leg 2: `grep IdleAction /etc/systemd/logind.conf`.
    import re
    conf = machine.succeed("grep IdleAction /etc/systemd/logind.conf")
    print("logind.conf:\n" + conf)
    assert re.search(r"(?m)^\s*IdleAction\s*=\s*lock\s*$", conf), f"IdleAction is not lock:\n{conf}"
    assert re.search(r"(?m)^\s*IdleActionSec\s*=\s*600\s*$", conf), f"IdleActionSec is not 600:\n{conf}"
    # And logind itself, not only its file: the running manager reports the same.
    machine.wait_for_unit("systemd-logind.service")
    logind = "org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager"
    action = machine.succeed(f"busctl get-property {logind} IdleAction").strip()
    assert action == 's "lock"', f"logind's IdleAction is {action}"
    usec = machine.succeed(f"busctl get-property {logind} IdleActionUSec").strip()
    assert usec == "t 600000000", f"logind's IdleActionUSec is {usec}, expected 600 s"

    # Leg 3 of the published check requires an xautolock user unit running with `-time 10`.
    # The control does NOT provide it, on purpose: xautolock watches an X11 server and does
    # nothing under a Wayland compositor, which is all this fleet runs. An assessor running
    # the check literally would record this leg as a finding. Asserted absent so the day
    # someone adds it, this comment and the control's rationale get revisited together.
    machine.fail("test -e /etc/systemd/user/xautolock.service")
  '')

  (spec "V-268101" "the audit daemon notifies at 75 percent of the audit volume" ''
    machine.wait_for_unit("auditd.service")
    # The check, verbatim. -w so admin_space_left_action (V-268102) does not match.
    line = machine.succeed("grep -w space_left_action /etc/audit/auditd.conf").strip()
    print(line)
    import re
    m = re.fullmatch(r"space_left_action\s*=\s*(\S+)", line)
    assert m, f"space_left_action is missing, commented out, blank or set twice: {line!r}"
    assert m.group(1).lower() == "syslog", f"space_left_action is {m.group(1)}, expected syslog"
    # auditd refuses to start on a configuration it cannot parse, so active means accepted.
    machine.succeed("systemctl is-active auditd.service | grep -qx active")
  '')

  (spec "V-268102" "the audit daemon notifies at 90 percent of the audit volume" ''
    machine.wait_for_unit("auditd.service")
    line = machine.succeed("grep -w admin_space_left_action /etc/audit/auditd.conf").strip()
    print(line)
    import re
    m = re.fullmatch(r"admin_space_left_action\s*=\s*(\S+)", line)
    assert m, f"admin_space_left_action is missing, commented out, blank or set twice: {line!r}"
    assert m.group(1).lower() == "syslog", f"admin_space_left_action is {m.group(1)}, expected syslog"
    machine.succeed("systemctl is-active auditd.service | grep -qx active")
  '')

  (spec "V-268132" "login.defs declares a one-day minimum password lifetime" ''
    # The check, verbatim. This is what the control is scored on, and it passes.
    import re
    defs = machine.succeed("grep PASS_MIN_DAYS /etc/login.defs")
    m = re.search(r"(?m)^\s*PASS_MIN_DAYS\s+(\d+)\s*$", defs)
    assert m, f"PASS_MIN_DAYS is missing or commented out:\n{defs}"
    assert int(m.group(1)) == 1, f"PASS_MIN_DAYS is {m.group(1)}, expected 1"

    ${newAccountAging}
    # Field 4 of a shadow entry is the minimum age in days, and it is EMPTY: the setting the
    # check greps for has no consumer. shadow 4.20 (the version this nixpkgs ships) no longer
    # implements a minimum password age. useradd writes sp_min = -1 unconditionally where it
    # used to read PASS_MIN_DAYS, and the login.defs manual no longer documents the key. So
    # the line is in the file, the published check passes, and no account is held to it.
    #
    # Pinned as observed rather than left out, for the same reason V-268078 pins the missing
    # firewall-panic: a test that only ran the grep would report a one-day minimum that does
    # not exist. If this assertion ever fails, shadow honours the key again and it should
    # become `== "1"`.
    assert fields[3] == "", (
        f"a new account's minimum password age is {fields[3]!r}; shadow was expected to leave "
        "it unset (see the comment above this assertion)"
    )
  '')

  (spec "V-268133" "a password expires after 180 days" ''
    import re
    defs = machine.succeed("grep PASS_MAX_DAYS /etc/login.defs")
    m = re.search(r"(?m)^\s*PASS_MAX_DAYS\s+(\d+)\s*$", defs)
    assert m, f"PASS_MAX_DAYS is missing or commented out:\n{defs}"
    # The requirement is a 180-day MAXIMUM lifetime, so a longer one is the finding. (The
    # check's last sentence says "less than 180", which contradicts the requirement it
    # verifies; 180 exactly satisfies both readings.)
    assert int(m.group(1)) == 180, f"PASS_MAX_DAYS is {m.group(1)}, expected 180"

    ${newAccountAging}
    # Field 5 is the maximum age in days.
    assert fields[4] == "180", f"a new account's maximum password age is {fields[4]!r}, expected 180"
  '')

  (spec "V-268134" "a password must be at least 15 characters" ''
    import re
    pwq = machine.succeed("grep minlen /etc/security/pwquality.conf")
    m = re.search(r"(?m)^\s*minlen\s*=\s*(\d+)\s*$", pwq)
    assert m, f"minlen is missing or commented out:\n{pwq}"
    assert int(m.group(1)) >= 15, f"minlen is {m.group(1)}, must be at least 15"

    # minlen joins the file six base-safe controls already write; none of theirs may be lost.
    whole = machine.succeed("cat /etc/security/pwquality.conf")
    for key in ["ucredit", "lcredit", "dcredit", "ocredit", "difok", "dictcheck"]:
        assert re.search(rf"(?m)^\s*{key}\s*=", whole), f"{key} was lost in the merge:\n{whole}"
  '')

  (specWith [
      {
        users.users.stigtest = {
          isNormalUser = true;
          uid = 1000;
        };
        users.users.stigother = {
          isNormalUser = true;
          uid = 1001;
        };
      }
    ]
    "V-268135" "no two accounts share a UID" ''
      # The check, verbatim. It prints an account for every UID seen a second time; the check
      # only counts interactive accounts, and this asserts the stronger thing, no output.
      duplicates = machine.succeed(
          "awk -F ':' 'list[$3]++{print $1, $3}' /etc/passwd"
      ).strip()
      assert duplicates == "", f"accounts sharing a UID: {duplicates}"
      # Two interactive accounts exist, so the line above compared something.
      machine.succeed("test \"$(id -u stigtest)\" != \"$(id -u stigother)\"")

      # What this does NOT show is the control's own mechanism. V-268135 is an eval-time
      # assertion: a configuration with a duplicated UID fails to build, so there is no
      # machine to boot. That refusal is proven in controls/V-268135.assay.nix.
    '')

  (spec "V-268136" "the PKCS#11 tooling for multifactor authentication is installed" ''
    # The check, verbatim, including the path it expects.
    path = machine.succeed("which p11sak").strip()
    assert path == "/run/current-system/sw/bin/p11sak", f"p11sak resolved to {path}"
    # Present and runnable, not a dangling link.
    machine.succeed("p11sak --version")
  '')

  (specWith [
      {
        users.users.stigadmin = {
          isNormalUser = true;
          extraGroups = ["wheel"];
        };
        users.users.stiguser.isNormalUser = true;
      }
    ]
    "V-268152" "only root and wheel may use the nix daemon" ''
      # The published check greps /etc/nixos for the option. A flake-deployed host has no
      # /etc/nixos, so read what that option renders to: the daemon's own configuration.
      conf = machine.succeed("cat /etc/nix/nix.conf")
      import re
      m = re.search(r"(?m)^\s*allowed-users\s*=\s*(.*)$", conf)
      assert m, f"allowed-users is not set in nix.conf:\n{conf}"
      allowed = sorted(m.group(1).split())
      assert allowed == ["@wheel", "root"], f"allowed-users is {allowed}, expected root and @wheel only"

      # And the daemon enforces it. Querying the store as a non-root user goes through the
      # daemon socket: a wheel member is served, anyone else is refused.
      machine.wait_for_unit("nix-daemon.socket")
      query = "nix-store --query --references /run/current-system"
      machine.succeed(f"su - stigadmin -c '{query}'")
      status, out = machine.execute(f"su - stiguser -c '{query}' 2>&1")
      print("non-wheel user was told:\n" + out)
      assert status != 0, "a user outside wheel was served by the nix daemon"
      # The client only sees its connection dropped; the reason is in the daemon's journal.
      machine.succeed(
          "journalctl -u nix-daemon --no-pager "
          "| grep -F \"user 'stiguser' is not allowed to connect to the Nix daemon\""
      )
      machine.fail("journalctl -u nix-daemon --no-pager | grep -F \"user 'stigadmin' is not allowed\"")
    '')

  (specWith [
      ({lib, ...}: {
        # The fleet's own sudo feature sets a never-expiring credential cache in the same
        # option (features/nixos/security/sudo). Reproduced here because that is the line
        # this control has to beat on a real host, and once did not.
        security.sudo.extraConfig = lib.mkBefore ''
          Defaults timestamp_timeout=-1
        '';
        users.users.stigadmin = {
          isNormalUser = true;
          extraGroups = ["wheel"];
          initialPassword = "correct-horse-battery-staple";
        };
      })
    ]
    "V-268155" "every sudo invocation asks for the password again" ''
      # The check, verbatim. sudoers takes the LAST Defaults for a setting, so that is the one
      # that must read 0.
      lines = machine.succeed("grep timestamp_timeout /etc/sudoers").strip().splitlines()
      print("\n".join(lines))
      active = [line.split("=")[-1].strip() for line in lines if not line.strip().startswith("#")]
      assert active, "timestamp_timeout is missing or commented out"
      assert active[-1] == "0", f"the timestamp_timeout in effect is {active[-1]}, expected 0: {lines}"

      # What sudo itself resolved after parsing the whole file.
      resolved = machine.succeed("sudo -V | grep -i 'timestamp timeout'").strip()
      assert resolved.endswith(": 0.0 minutes"), f"sudo resolved: {resolved}"

      # And the behaviour: a successful, password-authenticated sudo leaves no credential
      # behind, so the very next one in the same shell cannot run without asking (-n).
      machine.succeed(
          "su - stigadmin -c '"
          "echo correct-horse-battery-staple | sudo -S -p \"\" true && ! sudo -n true"
          "'"
      )
    '')

  (specWith [withGdm withUser] "V-268172" "nobody is logged on without authenticating" ''
    # The published check greps /etc/nixos for an option name that does not exist
    # (`autologon.user`; see the control). It returns nothing on any host, so it cannot fail.
    machine.fail("grep -iR autologon.user /etc/nixos")

    # What it means to verify: the machine boots to a greeter and a login prompt, and no
    # one is logged on. Three places an automatic logon could come from.
    machine.wait_for_unit("display-manager.service")

    # 1. GDM, the consumer of services.displayManager.autoLogin.
    machine.fail("grep -qiE '^\\s*(Timed|Automatic)LoginEnable\\s*=\\s*true' /etc/gdm/custom.conf")

    # 2. The virtual consoles. (tty1 belongs to the greeter here, so there is no getty on it
    #    to wait for; the template every console getty is started from is what is read.)
    machine.succeed("systemctl cat getty@.service | grep -q agetty")
    machine.fail("systemctl cat getty@.service | grep -q -- '--autologin'")
    machine.fail("pgrep -a agetty | grep -q -- '--autologin'")

    # 3. The result: once the greeter is up, logind has no session of class `user`. The
    #    greeter's own session is class `greeter` and is expected.
    machine.wait_until_succeeds("loginctl list-sessions --no-legend | grep -q .", timeout=180)
    sessions = machine.succeed("loginctl list-sessions --no-legend").strip().splitlines()
    print("sessions:", sessions)
    for session in sessions:
        sid = session.split()[0]
        cls = machine.succeed(f"loginctl show-session {sid} -p Class --value").strip()
        who = machine.succeed(f"loginctl show-session {sid} -p Name --value").strip()
        assert cls != "user", f"{who} has a user session ({sid}) on a machine nobody logged on to"
    assert machine.succeed("who").strip() == "", "utmp lists a logged-on user"

    # The control's own mechanism is an eval-time assertion: a configuration that enables
    # autoLogin does not build. That refusal is proven in controls/V-268172.assay.nix.
  '')

  (spec "V-268174" "an account is disabled after 35 days of inactivity" ''
    # The check, verbatim.
    import re
    conf = machine.succeed("grep -i inactive /etc/default/useradd")
    m = re.search(r"(?m)^\s*INACTIVE\s*=\s*(-?\d+)\s*$", conf)
    assert m, f"INACTIVE is missing or commented out:\n{conf}"
    # "35 or less" -- but -1 means never and 0 disables at the moment of expiry.
    assert 0 <= int(m.group(1)) <= 35, f"INACTIVE is {m.group(1)}, must be 0..35"

    # useradd reads the file: its defaults report the same value, and the three lines nixpkgs
    # writes there survived this control replacing the file.
    defaults = machine.succeed("useradd -D")
    print("useradd -D:\n" + defaults)
    assert re.search(r"(?m)^INACTIVE=35$", defaults), f"useradd does not see INACTIVE=35:\n{defaults}"
    for key in ["GROUP", "HOME", "SHELL"]:
        assert re.search(rf"(?m)^{key}=\S", defaults), f"{key} was lost from /etc/default/useradd:\n{defaults}"

    ${newAccountAging}
    # Field 7 is the inactivity period in days.
    assert fields[6] == "35", f"a new account's inactivity period is {fields[6]!r}, expected 35"
    # The home directory and shell defaults are what made the account usable.
    machine.succeed("test -d \"$(getent passwd stigprobe | cut -d: -f6)\"")
  '')
]
