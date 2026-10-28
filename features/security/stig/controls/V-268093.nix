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
# `audit_backlog_limit=8192` on the kernel command line twice.
#
# This control is not a no-op, unlike its neighbours V-268090 and V-268092: the nixpkgs
# default is 1024 and the STIG requires 8192, so the option must actually be raised.
{...}: {
  security.audit.backlogLimit = 8192;
}
