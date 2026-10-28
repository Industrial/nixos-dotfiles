# V-268145 (CAT II) — NixOS must enforce password complexity by requiring that at least one
# special character be used.
#
# Contributed through `security.stig.pwquality`; see that option's description.
{...}: {
  security.stig.pwquality.ocredit = -1;
}
