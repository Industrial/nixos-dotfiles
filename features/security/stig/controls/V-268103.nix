# V-268103 (CAT II) — NixOS must take action when allocated audit record storage volume
# reaches 75 percent of the repository maximum audit record storage capacity.
#
# The published fix text repeats the broken pattern from V-268110 — a list of strings assigned
# to `environment.etc."audit/auditd.conf".text`, which has type `str` — and would collide with
# the nixpkgs auditd module that generates that file. Declared through the owning option.
#
# `space_left = 25%` is the 75-percent threshold expressed from the other end: act when 25% of
# the volume remains. The action itself is V-268105's concern.
{...}: {
  security.auditd.settings.space_left = "25%";
}
