# V-268167 (CAT II) — NixOS must generate audit records for all account creations,
# modifications, disabling, and termination events.
#
# Six write+attribute watches on the identity databases, transcribed from the fix text.
#
# /etc/security/opasswd is the one that does not exist on a stock system — it is created by
# pam_pwhistory the first time a password is changed — and auditctl fails the ENTIRE rules
# file on a watch whose path is missing (see V-268165). It is therefore provisioned here.
#
# Creating it empty is safe: pam_pwhistory appends to it, and an empty file means "no previous
# passwords recorded", which is already true. Mode 0600 root:root, because it holds old
# password hashes once populated.
#
# Worth knowing for the VM test: on NixOS with `users.mutableUsers = false` these files are
# regenerated from the Nix store on every activation, so the watches fire on rebuild as well
# as on real account changes. That is noise, not a defect, and the fix text asks for it.
{...}: {
  systemd.tmpfiles.rules = [
    "f /etc/security/opasswd 0600 root root -"
  ];

  security.audit.rules = [
    "-w /etc/sudoers -p wa -k identity"
    "-w /etc/passwd -p wa -k identity"
    "-w /etc/shadow -p wa -k identity"
    "-w /etc/gshadow -p wa -k identity"
    "-w /etc/group -p wa -k identity"
    "-w /etc/security/opasswd -p wa -k identity"
  ];
}
