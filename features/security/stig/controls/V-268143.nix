# V-268143 (CAT II) — NixOS must terminate all SSH connections after becoming unresponsive.
#
# Fix text uses `services.openssh.extraConfig` with `ClientAliveCountMax 1`; declared as a
# freeform settings entry here for the same reason as V-268142.
#
# CountMax 1 means sshd gives up after a single unanswered keepalive, so with V-268142's
# 600-second interval a wedged session is torn down rather than held open indefinitely.
{...}: {
  services.openssh.settings.ClientAliveCountMax = 1;
}
