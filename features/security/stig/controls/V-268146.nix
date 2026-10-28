# V-268146 (CAT I) — NixOS must protect wireless access to and from the system using
# encryption.
#
# Fix text: networking.wireless.enable = false;
#
# The requirement is about protecting wireless with encryption; the fix text achieves it by
# removing wireless entirely. That is a legitimate reading — there is no unencrypted wireless
# if there is no wireless — but it is worth being clear that this control does not configure
# WPA, it disables Wi-Fi.
#
# On this fleet `networking.wireless.enable` already evaluates false, because the hosts use
# NetworkManager rather than wpa_supplicant directly. So the option is a no-op here and
# Wi-Fi keeps working through NetworkManager: the control as written does NOT actually
# disable wireless on these machines.
#
# That matters for the report. The check greps the option, so the host scores compliant while
# retaining Wi-Fi — a case where the published check does not measure what the requirement
# intends. Recorded for the justification column rather than papered over, and the VM test
# asserts the option state the check reads.
#
# `full` profile, CAT I.
{...}: {
  networking.wireless.enable = false;
}
