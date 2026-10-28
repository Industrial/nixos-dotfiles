# V-268110 (CAT II) — NixOS audit daemon must generate logs that are group-owned by root.
#
# The published fix text does not evaluate:
#
#   environment.etc."audit/auditd.conf".text = [
#    ''
#     log_group = root
#    ''
#   ];
#
# `environment.etc.<name>.text` has type `str`, and that assigns a list of strings to it, so
# applying the fix text literally is a type error. It would also fight the nixpkgs auditd
# module, which generates /etc/audit/auditd.conf itself — two definitions of one etc entry.
#
# The correct mechanism on current nixpkgs is the auditd module's own settings attrset, which
# renders auditd.conf. Same outcome, declared through the option that owns the file.
{...}: {
  security.auditd.settings.log_group = "root";
}
