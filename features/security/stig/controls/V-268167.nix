# V-268167 (CAT II) — NixOS must generate audit records for all account creations,
# modifications, disabling, and termination events.
#
# Six write+attribute watches on the identity databases, transcribed from the fix text.
#
# Worth knowing for the VM test: on NixOS with `users.mutableUsers = false` these files are
# regenerated from the Nix store on every activation, so the watches fire on rebuild as well
# as on real account changes. That is noise, not a defect, and the fix text asks for it.
{...}: {
  security.audit.rules = [
    "-w /etc/sudoers -p wa -k identity"
    "-w /etc/passwd -p wa -k identity"
    "-w /etc/shadow -p wa -k identity"
    "-w /etc/gshadow -p wa -k identity"
    "-w /etc/group -p wa -k identity"
    "-w /etc/security/opasswd -p wa -k identity"
  ];
}
