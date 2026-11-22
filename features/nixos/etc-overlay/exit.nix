# Leaving the /etc overlay (GH-185): the half of features/nixos/etc-overlay that runs in a
# generation WITHOUT it. A part of features.nixos (imported by features/nixos/default.nix),
# so it is on every host, and inert unless a previous overlay period left an upperdir
# behind that has not been carried out yet (/.rw-etc/upper without /.rw-etc/.exited).
#
#   - live, `switch-to-configuration` out of the overlay: /etc is still the overlay mount.
#     The plain /etc under it is reached through a non-recursive bind mount of /, every
#     stateful file of the upperdir is copied there from the merged /etc, and the overlay
#     and its metadata image are lazily unmounted, all before upstream's `etc` step, so
#     setup-etc.pl then runs on the plain /etc as always;
#   - at boot into such a generation: the activation finds a plain /etc and copies from
#     the upperdir directly.
#
# Then /.rw-etc/.exited is written: the upperdir is history, and the next entry into the
# overlay moves it aside and starts again from this /etc. What is copied: ./carry.nix.
#
# Generations built before this module existed do not carry anything out: booting one of
# those after an overlay period brings back the /etc from before it.
{
  config,
  lib,
  pkgs,
  ...
}: let
  carry = import ./carry.nix {inherit pkgs lib;};
  etcTree = "${config.system.build.etc}/etc";
in {
  config = lib.mkIf (!config.system.etc.overlay.enable) {
    system.activationScripts.etcOverlayCarryOut = lib.stringAfter ["users" "groups" "specialfs"] ''
      if [ -d /.rw-etc/upper ] && [ ! -e /.rw-etc/.exited ]; then
        if [ "$(findmnt -n -o FSTYPE --mountpoint /etc 2>/dev/null)" = overlay ]; then
          _etc_plain=$(mktemp -d /run/etc-overlay-exit.XXXXXXXXXX)
          mount --bind / "$_etc_plain"
          mount --make-private "$_etc_plain"
          ${carry.carryOut} /.rw-etc/upper /etc "$_etc_plain/etc" ${etcTree} /.rw-etc/.carried
          umount "$_etc_plain"
          rmdir "$_etc_plain"
          umount --lazy --recursive /etc
          findmnt --type erofs --list --noheading --kernel --output TARGET | while read -r _m; do
            case "$_m" in
              /run/nixos-etc-metadata*) umount --lazy "$_m" && rmdir "$_m" 2>/dev/null ;;
            esac
          done
        else
          ${carry.carryOut} /.rw-etc/upper /.rw-etc/upper /etc ${etcTree} /.rw-etc/.carried
        fi
        touch /.rw-etc/.exited
      fi
    '';
    system.activationScripts.etc.deps = ["etcOverlayCarryOut"];
  };
}
