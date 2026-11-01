# Colocated suite for features/nixos/graphics/intel.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./intel.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "intel" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;

    # The pieces that make the Intel stack actually accelerate anything. A silent regression
    # here looks like working graphics with software video decode, so assert them explicitly.
    vaapiDriver = assay.eq (has ".*intel-media-driver.*") true;
    quickSyncRuntime = assay.eq (has ".*vpl-gpu-rt.*") true;
    selectsIhdNotI965 = assay.eq (has ".*LIBVA_DRIVER_NAME = \"iHD\";.*") true;

    # Early KMS, so the boot-time LUKS prompt is legible on a HiDPI panel. (No escaped
    # brackets: builtins.match is POSIX ERE, where `\[` is not a valid escape.)
    earlyKms = assay.eq (has ".*initrd.*kernelModules = .*\"i915\".*") true;
  }
