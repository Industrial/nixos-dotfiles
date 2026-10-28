# V-268128 (CAT II) — NixOS must enforce password complexity by requiring that at least one
# numeric character be used.
#
# Contributed through `security.stig.pwquality`; see that option's description.
{...}: {
  security.stig.pwquality.dcredit = -1;
}
