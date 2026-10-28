# V-268160 (CAT II) — NixOS must implement nonexecutable data to protect its memory from
# unauthorized code execution.
#
# The requirement is about NX/DEP. The fix and check are about something else entirely:
#
#   $ sudo sysctl kernel.kptr_restrict
#   kernel.kptr_restrict = 1
#   If "kernel.kptr_restrict" does not have a value of "1" or is missing, this is a finding.
#
# kernel pointer restriction is an information-leak mitigation; it has nothing to do with
# non-executable data pages. We implement what the check verifies, because that is what an
# assessor runs, and the title/mechanism mismatch goes in the report's justification column.
#
# Two traps, both load-bearing:
#   - The check is an EQUALITY test against 1. kptr_restrict = 2 is stricter and would be
#     scored as a FINDING. Do not "improve" this value. (ADR-0003 records that the deleted
#     features/security/kernel module proposed exactly that.)
#   - NX itself is not configured here at all; on any x86_64 kernel NixOS builds it is on by
#     default and not controlled by a sysctl.
{...}: {
  boot.kernel.sysctl."kernel.kptr_restrict" = 1;
}
