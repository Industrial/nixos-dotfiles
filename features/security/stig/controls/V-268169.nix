# V-268169 (CAT II) — NixOS must prevent the use of dictionary words for passwords.
#
# Fix text: dictcheck=1.
#
# Contributed through `security.stig.pwquality`; see that option's description.
#
# Worth noting: V-268170's *check* text is mislabelled — it is headed "Verify NixOS prevents
# the use of dictionary words for passwords", which is this control's requirement, but then
# greps for pam_pwquality in the PAM files. The two controls are related (dictcheck does
# nothing until pam_pwquality is loaded) but they are not the same requirement.
{...}: {
  security.stig.pwquality.dictcheck = 1;
}
