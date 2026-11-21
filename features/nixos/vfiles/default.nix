# vfiles takes over placing the files features declare in users' homes (GH-188).
#
# Every feature that used to write or link a dotfile from its own activation script now
# declares it in `vfiles.files` (lib/vfiles.nix) and keeps the old script only as
# `vfiles.legacy.<name>`. With this feature on, those legacy scripts are gone and one
# activation step runs rust/tools/vfiles over the whole set: atomic placement, a manifest
# of what it owns (/var/lib/vfiles/manifest.json), removal of what a dropped feature
# left, and drift reported instead of clobbered (/var/lib/vfiles/report.json).
#
# Rollback: `features.nixos.vfiles.enable = lib.mkForce false;` on the host brings every
# legacy script back.
#
# Health probe (on the host): the dry run decides without changing anything and prints
# the report; nothing failed, and drift lists only files a person edited:
#   vfiles --dry-run --spec /etc/vfiles/spec.json | jq -e '.failed == []'
{...}: {
  imports = [../../../lib/vfiles.nix];

  vfiles.enable = true;
}
