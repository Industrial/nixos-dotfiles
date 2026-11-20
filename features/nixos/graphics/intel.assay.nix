# Assay: Intel graphics vendor module (Gen12 "Xe" and newer).
#
# The pieces that make the Intel stack actually accelerate anything. A silent regression here
# looks like working graphics with software video decode, so they are asserted explicitly --
# against the evaluated hardware.graphics / initrd / session options, not the module text.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./intel.nix];};
  extra = map lib.getName cfg.hardware.graphics.extraPackages;
in
  assay.suite "intel" {
    vaapiDriver = assay.eq (builtins.elem "intel-media-driver" extra) true;
    quickSyncRuntime = assay.eq (builtins.elem "vpl-gpu-rt" extra) true;
    openclRuntime = assay.eq (builtins.elem "intel-compute-runtime" extra) true;
    # Without this, libva picks the legacy i965 driver, which has no Gen12 support.
    selectsIhdNotI965 = assay.eq cfg.environment.sessionVariables.LIBVA_DRIVER_NAME "iHD";

    # Early KMS, so the boot-time LUKS prompt is legible on a HiDPI panel.
    earlyKms = assay.eq (builtins.elem "i915" cfg.boot.initrd.kernelModules) true;
    # A host imports exactly one vendor module; this one brings no amdgpu.
    noAmdgpuInInitrd = assay.eq (builtins.elem "amdgpu" cfg.boot.initrd.kernelModules) false;
  }
