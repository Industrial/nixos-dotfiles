# V-268155 (CAT II) — NixOS must require users to reauthenticate for privilege escalation.
#
# Fix text: security.sudo.extraConfig = "Defaults timestamp_timeout=0";
#
# timestamp_timeout=0 disables sudo's credential cache entirely, so every single sudo
# invocation prompts — not just the first in a session. That is stricter than V-268156, which
# only requires that sudo asks at all.
#
# `full` profile, and genuinely disruptive: any script that runs several sudo commands in
# sequence now prompts for each one. It also interacts with `bin/fleet deploy`, which relies
# on the NOPASSWD rules in features/fleet/operator-ssh.nix — those are explicit per-command
# exemptions and survive, but a deploy that fell back to interactive sudo would prompt
# repeatedly with no tty.
#
# mkAfter, and it is load-bearing. features/nixos/security/sudo, which every host carries,
# sets `Defaults timestamp_timeout=-1` (never expire) in the same option. `extraConfig` is
# concatenated, and in sudoers the LAST `Defaults` for a setting wins, so without an ordering
# this control's line can be rendered first and overridden: on muninn the file read
# `timestamp_timeout=0` followed by `timestamp_timeout=-1`, a control present in the file and
# not in effect. mkAfter puts this line after the fleet's.
{lib, ...}: {
  security.sudo.extraConfig = lib.mkAfter ''
    Defaults timestamp_timeout=0
  '';
}
