# VM test specs for the two controls that live in the PAM stacks: the three-strike lockout
# (V-268081) and password quality (V-268170).
#
# Every other spec in this directory reads a file or a kernel value, because that is what the
# control's check does. These two do more, on purpose. Both controls shipped once as modules
# whose PAM line was present and did nothing (GH-349, ADR-0008): the check text, which only
# greps /etc/pam.d, passed on a machine where no account could be locked and no weak password
# was refused. So each spec runs the check AND then does the thing the control forbids, at a
# real console and with the real `passwd`, and asserts that the machine refuses.
#
# Both specs fail against the earlier module text. That was demonstrated once when the
# modules were reworked; it is not kept as a test.
{...}: let
  profile = ./../../profiles/base-safe.nix;

  # Passwords for the test accounts. They are set as hashes by the user module, which does
  # not go through PAM, so they need not satisfy the policy under test — but the ones that
  # V-268170 changes must, since the old password is compared with the new one (difok).
  goodPassword = "aB3$fG6&jK9)mN2!qR";

  # Typing at a virtual console and reading the tally: shared with ../test-host-logon.nix.
  consoleHelpers = import ./console.nix;
in [
  {
    id = "V-268081";
    description = "three consecutive failed logons lock the account until root resets it";
    modules = [profile ./../../controls/V-268081.nix];
    extraModules = [
      {
        services.openssh.enable = true;
        users.users = {
          # Locked out by the test.
          mallory = {
            isNormalUser = true;
            password = goodPassword;
          };
          # Fails twice, then logs on: the tally must clear.
          alice = {
            isNormalUser = true;
            password = goodPassword;
          };
          # Never fails. Someone else's lock must not touch this account.
          bob = {
            isNormalUser = true;
            password = goodPassword;
          };
        };
      }
    ];
    script = ''
      ${consoleHelpers}

      # --- the check text ---------------------------------------------------------------
      # `cat /etc/pam.d/login`: a pam_faillock preauth line whose fail_interval is 900 or
      # less and not 0.
      login = machine.succeed("cat /etc/pam.d/login")
      print("/etc/pam.d/login:\n" + login)
      preauth = [
          line for line in login.splitlines()
          if line.startswith("auth") and "pam_faillock.so preauth" in line
      ]
      assert len(preauth) == 1, f"expected one pam_faillock preauth line:\n{login}"
      assert preauth[0].split()[1] == "required", preauth[0]
      interval = re.search(r"\bfail_interval=(\d+)\b", preauth[0])
      assert interval and 0 < int(interval.group(1)) <= 900, preauth[0]
      for setting in ["deny=3", "unlock_time=0", "audit"]:
          assert re.search(rf"\b{setting}\b", preauth[0]), f"{setting} missing: {preauth[0]}"

      # The order of the three calls is the whole control. Read it off the rendered file:
      # preauth, then every pam_unix, then authfail directly behind the last pam_unix.
      auth = [line for line in login.splitlines() if line.startswith("auth")]


      def where(needle):
          return [i for i, line in enumerate(auth) if needle in line]


      assert where("pam_faillock.so preauth")[0] < where("pam_unix.so")[0], auth
      assert where("pam_faillock.so authfail") == [where("pam_unix.so")[-1] + 1], auth
      assert auth[where("pam_faillock.so authfail")[0]].split()[1] == "[default=die]", auth
      for stack in ["login", "sshd"]:
          machine.succeed(f"grep -E '^account required \\S+/pam_faillock\\.so' /etc/pam.d/{stack}")
          machine.succeed(f"grep -E '^auth required \\S+/pam_faillock\\.so preauth' /etc/pam.d/{stack}")

      # --- "consecutive": a successful logon clears the tally ---------------------------
      assert failures("alice") == 0
      refused(2, "alice", "wrong-password-1")
      refused(2, "alice", "wrong-password-2")
      assert failures("alice") == 2, machine.succeed("faillock --user alice")
      accepted(2, "alice", "${goodPassword}")
      assert failures("alice") == 0, (
          "a successful logon did not clear the tally:\n" + machine.succeed("faillock --user alice")
      )

      # --- three strikes ---------------------------------------------------------------
      for attempt in range(1, 4):
          refused(3, "mallory", f"wrong-password-{attempt}")
          assert failures("mallory") == attempt, machine.succeed("faillock --user mallory")

      # The account is now locked: the CORRECT password is refused. This is the assertion
      # the earlier module could not pass, since it never recorded a failure.
      refused(3, "mallory", "${goodPassword}")
      print(machine.succeed("faillock --user mallory"))
      assert failures("mallory") >= 3

      # unlock_time=0: the lock does not expire. Waiting proves little in a test, so read
      # the setting the module is running with instead of sleeping for an arbitrary time.
      assert "unlock_time=0" in preauth[0]
      # What does end it without an administrator is a reboot: the tally is on a tmpfs. The
      # control keeps it there on purpose (no dir=), so pin where it is.
      machine.succeed("test -s /run/faillock/mallory")
      assert machine.succeed("findmnt -n -o FSTYPE -T /run/faillock").strip() == "tmpfs"

      # Someone else's lock is theirs alone.
      accepted(4, "bob", "${goodPassword}")

      # --- SSH with a key ----------------------------------------------------------------
      # A key logon does not pass through the auth stack. The control decides it is neither
      # blocked by the lock nor a way to clear it (see the module comment).
      machine.wait_for_unit("sshd.service")
      machine.succeed(
          "ssh-keygen -q -t ed25519 -N ''' -f /root/stig-test-key",
          "install -d -m 0700 -o mallory -g users /home/mallory/.ssh",
          "install -m 0600 -o mallory -g users /root/stig-test-key.pub /home/mallory/.ssh/authorized_keys",
      )
      ssh = (
          "ssh -i /root/stig-test-key -o BatchMode=yes -o StrictHostKeyChecking=no "
          "-o UserKnownHostsFile=/dev/null mallory@localhost"
      )
      before = failures("mallory")
      assert machine.succeed(f"{ssh} id -un").strip() == "mallory"
      assert failures("mallory") == before, (
          "a key logon changed the tally:\n" + machine.succeed("faillock --user mallory")
      )
      # Still locked at the console afterwards.
      refused(5, "mallory", "${goodPassword}")

      # --- released by an administrator -------------------------------------------------
      machine.succeed("faillock --user mallory --reset")
      assert failures("mallory") == 0
      accepted(5, "mallory", "${goodPassword}")
    '';
  }

  {
    id = "V-268170";
    description = "passwd refuses a password that fails the pwquality policy";
    modules = [
      profile
      ./../../controls/V-268134.nix # minlen 15, so the length rule is the benchmark's
      ./../../controls/V-268170.nix
    ];
    extraModules = [
      {
        users.users = {
          changer = {
            isNormalUser = true;
            password = goodPassword;
          };
          operator = {
            isNormalUser = true;
            extraGroups = ["wheel"];
            password = goodPassword;
          };
        };
      }
    ];
    script = ''
      import re

      # --- the check text ---------------------------------------------------------------
      # `grep -i pam_pwquality /etc/pam.d/passwd /etc/pam.d/chpasswd /etc/pam.d/sudo`: a
      # `password requisite .../pam_pwquality.so` line in each.
      for service in ["passwd", "chpasswd", "sudo"]:
          pam = machine.succeed(f"cat /etc/pam.d/{service}")
          password = [line for line in pam.splitlines() if line.startswith("password")]
          print(f"/etc/pam.d/{service} password stack:\n" + "\n".join(password))
          quality = [i for i, line in enumerate(password) if "pam_pwquality.so" in line]
          unix = [i for i, line in enumerate(password) if "pam_unix.so" in line]
          assert len(quality) == 1 and len(unix) == 1, password
          assert password[quality[0]].split()[1] == "requisite", password[quality[0]]
          # The earlier module rendered this line too, BEHIND a `sufficient` pam_unix.
          assert quality[0] < unix[0], f"{service}: pam_pwquality is behind pam_unix: {password}"
          assert "use_authtok" in password[unix[0]].split(), password[unix[0]]

      print(machine.succeed("cat /etc/security/pwquality.conf"))


      def shadow(user):
          return machine.succeed(f"getent shadow {user}").split(":")[1]


      def is_password(user, password):
          """Whether `password` is what the user's SHA-512 shadow entry stores."""
          _, method, salt, _ = shadow(user).split("$")
          assert method == "6", f"{user} is not hashed with SHA-512: {shadow(user)}"
          made = machine.succeed(f"mkpasswd -m sha-512 -S '{salt}' '{password}'").strip()
          return made == shadow(user)


      def passwd_as(user, old, new):
          """Run `passwd` as the user. Returns (exit status, output)."""
          # Old password once, then the new one more often than any retry setting asks.
          answers = " ".join(f"'{answer}'" for answer in [old] + [new] * 8)
          return machine.execute(f"printf '%s\\n' {answers} | su {user} -c passwd 2>&1")


      assert is_password("changer", "${goodPassword}")
      original = shadow("changer")

      # --- weak passwords are refused ---------------------------------------------------
      weak = {
          "shorter than 15 characters": "xQ7!pL2@",
          "one character class only": "qwhzjvkpmxntrbfyga",
          "no special character": "xQ7pL2mZ9vK4nR8wT",
          # Long enough, with all four classes: only the dictionary check (V-268169) can
          # refuse it. cracklib strips the last two characters and finds the word.
          "a dictionary word with a digit and a symbol appended": "Misunderstanding1!",
      }
      for why, candidate in weak.items():
          status, out = passwd_as("changer", "${goodPassword}", candidate)
          print(f"{why}: exit {status}\n{out}")
          assert status != 0, f"passwd accepted a password that is {why}"
          assert "BAD PASSWORD" in out, f"pam_pwquality did not speak for: {why}\n{out}"
          assert shadow("changer") == original, f"the password changed to one that is {why}"

      # --- a compliant password is accepted ---------------------------------------------
      compliant = "9vK#mQ2$xLp7!Wz@4Ns"
      assert len(compliant) >= 15
      status, out = passwd_as("changer", "${goodPassword}", compliant)
      print(f"compliant: exit {status}\n{out}")
      assert status == 0, f"passwd refused a compliant password:\n{out}"
      assert is_password("changer", compliant), "the stored password is not the one given"

      # --- root's paths: warned, not refused --------------------------------------------
      # pam_pwquality enforces for root only with `enforce_for_root`, which no control in
      # the benchmark sets. chpasswd runs as root, so the module is in its stack (which is
      # what the check asks) and its verdict is advisory there. Pinned so that the scope of
      # the control is a tested fact and a change in either direction is seen.
      settings = machine.succeed("cat /etc/security/pwquality.conf")
      assert not re.search(r"(?m)^\s*enforce_for_root", settings), settings
      warned = machine.succeed("echo 'changer:xQ7!pL2@' | chpasswd 2>&1")
      assert "BAD PASSWORD" in warned, f"pam_pwquality was not consulted by chpasswd: {warned}"
      assert is_password("changer", "xQ7!pL2@"), "chpasswd as root did not set the password"
      # And a compliant one goes through the same stack.
      machine.succeed("echo 'changer:${goodPassword}' | chpasswd")
      assert is_password("changer", "${goodPassword}")

      # --- sudo still authenticates -----------------------------------------------------
      # The control edits sudo's PASSWORD stack. Its auth stack must be untouched: the
      # published fix text would have removed it.
      assert machine.succeed(
          "printf '%s\\n' '${goodPassword}' | su operator -c 'sudo -S -k id -un'"
      ).strip() == "root"
      machine.fail("printf 'wrong-password\\n' | su operator -c 'sudo -S -k id -un'")
    '';
  }
]
