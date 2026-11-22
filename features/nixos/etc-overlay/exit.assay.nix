# Assay: features/nixos/etc-overlay/exit.nix, the carry-out that runs in every generation
# without the overlay. Evaluated alone (it is a part of features.nixos on a host): present
# and ordered before setup-etc.pl when the overlay is off, absent when it is on.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  eval = overlay: nixos.eval {modules = [./exit.nix {system.etc.overlay.enable = overlay;}];};
  off = eval false;
  on = eval true;
  script = off.system.activationScripts.etcOverlayCarryOut;
in
  assay.suite "etc-overlay-exit" {
    presentWithoutTheOverlay = assay.eq (off.system.activationScripts ? etcOverlayCarryOut) true;
    absentWithTheOverlay = assay.eq (on.system.activationScripts ? etcOverlayCarryOut) false;
    beforeSetupEtc = assay.eq (builtins.elem "etcOverlayCarryOut" off.system.activationScripts.etc.deps) true;
    afterTheUsers = assay.eq (lib.all (d: builtins.elem d script.deps) ["users" "groups" "specialfs"]) true;
    # Inert until an overlay period left an upperdir that was not carried out yet.
    guarded = assay.eq (lib.hasInfix "if [ -d /.rw-etc/upper ] && [ ! -e /.rw-etc/.exited ]" script.text) true;
    # Live: the plain /etc under the overlay, through a bind mount of / that does not recurse.
    reachesThePlainEtc = assay.eq (lib.hasInfix "mount --bind / \"$_etc_plain\"" script.text) true;
    unmountsTheOverlay = assay.eq (lib.hasInfix "umount --lazy --recursive /etc" script.text) true;
    marksItDone = assay.eq (lib.hasInfix "touch /.rw-etc/.exited" script.text) true;
  }
