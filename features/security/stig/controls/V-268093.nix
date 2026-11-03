# V-268093 (CAT II) — NixOS must allocate an audit_backlog_limit of sufficient size to capture
# processes that start prior to the audit daemon.
#
# The fix text lists two things:
#
#   boot.kernelParams = [ "audit_backlog_limit=8192" ];
#   security.audit.backlogLimit = 8192;
#
# On current nixpkgs only the second is needed. nixos/modules/security/audit.nix derives the
# kernel parameter from the option:
#
#   "audit_backlog_limit=${toString cfg.backlogLimit}"
#
# so setting the option produces the command line, while setting both would put
# the parameter on the kernel command line twice.
#
# This control is not a no-op, unlike its neighbours V-268090 and V-268092: the nixpkgs
# default is 1024 and the STIG requires at least 8192, so the option must actually be raised.
#
# Why 65536 rather than the 8192 from the fix text: the STIG states a *floor* ("of sufficient
# size"), not an exact value, and 8192 is not sufficient on this fleet. V-268095 audits every
# unlink/rename/rmdir for auid>=1000, so any bulk deletion emits ~5 records per file. Deleting a
# 67 GB container store saturated an 8192-entry backlog continuously (measured: backlog
# oscillating 1.1k-8.0k against the limit, ~1300 records/sec, 955k records lost). Because
# backlog_wait_time defaults to 60s, an overflowing backlog puts the *calling syscall* into
# uninterruptible sleep, and overflow records are routed to printk under failure=1 — which
# serialises on console_sem and stalls every CPU, freezing the desktop in multi-second hitches.
#
# 65536 keeps the STIG floor satisfied with 8x headroom, so bursty metadata workloads drain
# instead of blocking userspace. The backlog is a bounded skb queue, so the cost is memory only
# and only while records are actually queued.
{...}: {
  security.audit.backlogLimit = 65536;
}
