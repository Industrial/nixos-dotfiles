# VM test specs for SSH and transport crypto.
#
# Every spec boots the real base-safe profile, so each test also proves that the eight SSH
# controls compose into one working sshd rather than eight settings that happen to evaluate.
# That matters more here than elsewhere: four of these controls were published against
# renamed or misspelled options (see V-268088, V-268089, V-268137, V-268159, V-268176), and a
# setting that silently lands on a dead attribute path still evaluates fine. Only a running
# sshd can show whether it took effect.
#
# Assertions read the EFFECTIVE configuration via `sshd -T`, not the generated file. sshd -T
# is what sshd itself resolves after defaults, Match blocks and include ordering, so it is
# the closest thing to what the daemon will actually negotiate.
{...}: let
  profile = ./../../profiles/base-safe.nix;

  sshReady = ''
    machine.wait_for_unit("sshd.service")
    machine.wait_for_open_port(22)
  '';

  # sshd -T prints effective settings as lowercase keys.
  effective = ''
    conf = machine.succeed("sshd -T")
  '';

  spec = id: description: script: {
    inherit id description;
    modules = [profile];
    script = sshReady + effective + script;
  };
in [
  (spec "V-268159" "an encrypted transport is running" ''
    machine.succeed("systemctl is-active sshd.service | grep -qx active")
    # Confidentiality and integrity come from the negotiated algorithms, not from the daemon
    # merely being up — those are V-268089 and V-268157.
    #
    # Case-insensitive: this sshd renders `-T` output with capitalised keys ("Port 22",
    # "UsePAM yes"), not the lowercase form the manual page shows. A literal lowercase
    # substring check fails here while the (?i) regexes in the other specs pass, which is
    # exactly how this was found.
    import re
    assert re.search(r"(?mi)^ciphers\s+\S", conf), f"sshd reports no cipher list:\n{conf}"
    assert re.search(r"(?mi)^macs\s+\S", conf), f"sshd reports no MAC list:\n{conf}"
  '')

  (spec "V-268088" "sshd logs at VERBOSE" ''
    import re
    m = re.search(r"(?mi)^loglevel\s+(\S+)", conf)
    assert m, f"sshd reports no loglevel:\n{conf}"
    assert m.group(1).upper() == "VERBOSE", f"loglevel is {m.group(1)}, expected VERBOSE"
  '')

  (spec "V-268089" "only approved ciphers are offered" ''
    import re
    m = re.search(r"(?mi)^ciphers\s+(.+)$", conf)
    assert m, f"sshd reports no ciphers:\n{conf}"
    ciphers = [c.strip() for c in m.group(1).split(",")]
    # The published fix text's `services.openssh.setting.Ciphers` typo would have left this
    # at sshd's default list while the control looked applied. This is the assertion that
    # would have caught it.
    assert ciphers == ["aes256-ctr", "aes192-ctr", "aes128-ctr"], f"unexpected ciphers: {ciphers}"
    assert not [c for c in ciphers if "cbc" in c], f"CBC cipher offered: {ciphers}"
    assert not [c for c in ciphers if "chacha" in c], f"non-approved cipher offered: {ciphers}"
  '')

  (spec "V-268157" "only approved MACs are offered" ''
    import re
    m = re.search(r"(?mi)^macs\s+(.+)$", conf)
    assert m, f"sshd reports no MACs:\n{conf}"
    macs = [x.strip() for x in m.group(1).split(",")]
    assert macs == ["hmac-sha2-512", "hmac-sha2-256"], f"unexpected MACs: {macs}"
    assert not [x for x in macs if "md5" in x or "sha1" in x], f"weak MAC offered: {macs}"
  '')

  (spec "V-268137" "root may not log in over SSH" ''
    import re
    m = re.search(r"(?mi)^permitrootlogin\s+(\S+)", conf)
    assert m, f"sshd reports no permitrootlogin:\n{conf}"
    value = m.group(1).lower()
    # "prohibit-password" would still allow key-based root login and is NOT what the control
    # asks for.
    assert value == "no", f"permitrootlogin is {value}, expected no"
  '')

  (spec "V-268142" "unresponsive sessions are closed after 10 minutes" ''
    import re
    m = re.search(r"(?mi)^clientaliveinterval\s+(\d+)", conf)
    assert m, f"sshd reports no clientaliveinterval:\n{conf}"
    assert int(m.group(1)) == 600, f"clientaliveinterval is {m.group(1)}, expected 600"
  '')

  (spec "V-268143" "a single unanswered keepalive ends the session" ''
    import re
    m = re.search(r"(?mi)^clientalivecountmax\s+(\d+)", conf)
    assert m, f"sshd reports no clientalivecountmax:\n{conf}"
    count = int(m.group(1))
    assert count == 1, f"clientalivecountmax is {count}, expected 1"
    # 0 would disable the mechanism entirely rather than tighten it.
    assert count > 0, "clientalivecountmax=0 disables keepalive teardown"
  '')

  (spec "V-268176" "SSH authenticates through PAM" ''
    import re
    m = re.search(r"(?mi)^usepam\s+(\S+)", conf)
    assert m, f"sshd reports no usepam:\n{conf}"
    assert m.group(1).lower() == "yes", f"usepam is {m.group(1)}, expected yes"
    # The consequence that makes this control matter: without PAM, the PAM-side controls
    # would cover console logins only. The sshd PAM stack must exist.
    machine.succeed("test -e /etc/pam.d/sshd")
  '')
]
