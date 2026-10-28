# VM test specs for password complexity, hashing and logon delay.
#
# Six of these controls each require one setting in a single file, /etc/security/pwquality.conf,
# and the published fix texts all assign that file's contents directly — making them mutually
# exclusive. security.stig.pwquality merges them instead, and these tests are what prove the
# merge produced every setting rather than the last one to win.
#
# Note what is NOT asserted here: that a weak password is actually rejected. Enforcement needs
# pam_pwquality wired into the PAM stack, which is V-268170 — a `full` profile control,
# because a bad PAM line breaks password changes. Each check in this group greps the config
# file, which is the compliance these controls are scored on.
{...}: let
  profile = ./../../profiles/base-safe.nix;

  readPwquality = ''
    pwq = machine.succeed("cat /etc/security/pwquality.conf")
  '';

  spec = id: description: script: {
    inherit id description;
    modules = [profile];
    script = readPwquality + script;
  };

  # The checks grep for `<key>=<value>` and treat a positive credit as a finding.
  requiresClass = key: ''
    import re
    m = re.search(r"(?m)^\s*${key}\s*=\s*(-?\d+)\s*$", pwq)
    assert m, f"${key} is not set:\n{pwq}"
    value = int(m.group(1))
    # Negative means "require at least one of this class". A positive value instead grants
    # length credit for having one, which is the opposite of enforcement and is exactly what
    # the check rejects.
    assert value < 0, f"${key} is {value}; a positive value grants credit instead of requiring"
  '';
in [
  (spec "V-268126" "an uppercase character is required" (requiresClass "ucredit"))
  (spec "V-268127" "a lowercase character is required" (requiresClass "lcredit"))
  (spec "V-268128" "a numeric character is required" (requiresClass "dcredit"))
  (spec "V-268145" "a special character is required" (requiresClass "ocredit"))

  (spec "V-268169" "dictionary words are rejected" ''
    import re
    m = re.search(r"(?m)^\s*dictcheck\s*=\s*(\d+)\s*$", pwq)
    assert m, f"dictcheck is not set:\n{pwq}"
    assert int(m.group(1)) == 1, f"dictcheck is {m.group(1)}, expected 1"

    # The merge is the thing worth proving: all six settings that share this file must be
    # present together. Following the published fix texts literally would have produced six
    # conflicting definitions of one option.
    print("pwquality.conf:\n" + pwq)
    for key in ["ucredit", "lcredit", "dcredit", "ocredit", "difok", "dictcheck"]:
        assert re.search(rf"(?m)^\s*{key}\s*=", pwq), f"{key} was lost in the merge:\n{pwq}"
  '')

  (spec "V-268129" "half the characters must change on a password change" ''
    import re
    m = re.search(r"(?m)^\s*difok\s*=\s*(\d+)\s*$", pwq)
    assert m, f"difok is not set:\n{pwq}"
    difok = int(m.group(1))
    assert difok == 8, f"difok is {difok}, expected 8"
    # 8 is "at least 50 percent" only of the 15-character minimum in V-268134, which is a
    # `full` profile control. On base-safe this is an absolute count, which is weaker than the
    # requirement's wording implies.
    assert difok * 2 >= 15, "difok is not half of the 15-character minimum"
  '')

  (spec "V-268130" "passwords are hashed with SHA-512" ''
    machine.succeed("grep -qE '^\\s*ENCRYPT_METHOD\\s+SHA512' /etc/login.defs")
    # Not one of the weaker methods this setting also accepts.
    for weak in ["DES", "MD5", "SHA256"]:
        machine.fail(f"grep -qE '^\\s*ENCRYPT_METHOD\\s+{weak}' /etc/login.defs")
  '')

  (spec "V-268171" "a failed logon is followed by a four-second delay" ''
    import re
    defs = machine.succeed("cat /etc/login.defs")
    m = re.search(r"(?m)^\s*FAIL_DELAY\s+(\d+)", defs)
    assert m, f"FAIL_DELAY is not set:\n{defs}"
    # "at least four seconds" — a floor, so greater is still compliant.
    assert int(m.group(1)) >= 4, f"FAIL_DELAY is {m.group(1)}, expected at least 4"

    # Three controls write into login.defs; the merge must keep all of them.
    assert re.search(r"(?m)^\s*ENCRYPT_METHOD\s+SHA512", defs), "ENCRYPT_METHOD was lost"
    assert re.search(r"(?m)^\s*UMASK\s+077", defs), "UMASK was lost"
  '')
]
