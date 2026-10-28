# V-268148 (CAT II) — NixOS must prevent all software from executing at higher privilege
# levels than users executing the software.
#
# This control sets NOTHING, and that is deliberate.
#
# Its fix text asks for `security.auditd.enable`, `security.audit.enable`, and four audit
# rules that are **byte-identical** to the four in V-268091. Those requirements are already
# met by V-268080 (daemon) and V-268091 (rules).
#
# Emitting them again would append duplicate entries to `security.audit.rules`, which is a
# list. At best that loads the same rule twice; auditctl can also reject an exact duplicate,
# which would fail the audit-rules unit and take the *whole* audit subsystem down — turning a
# redundancy into an outage. Wave 2's VM test settles which it is; either way there is no
# reason to emit it.
#
# So the overlap is encoded in the colocated suite instead: it imports V-268091 and asserts
# that control still supplies exactly what V-268148 requires. If V-268091 ever changes, this
# control's suite fails and tells you V-268148 is no longer covered — which is the failure
# mode an "it's handled elsewhere" comment would hide.
{...}: {
  # Intentionally empty. See the comment above and ./V-268148.assay.nix.
}
