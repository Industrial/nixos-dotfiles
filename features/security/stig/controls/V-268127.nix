# V-268127 (CAT II) — NixOS must enforce password complexity by requiring that at least one
# lowercase character be used.
#
# Contributed through `security.stig.pwquality`; see that option's description.
{...}: {
  security.stig.pwquality.lcredit = -1;
}
