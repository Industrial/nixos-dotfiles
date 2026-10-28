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
{...}: {
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=0
  '';
}
