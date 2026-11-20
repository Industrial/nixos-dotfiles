# Assay: AMD graphics vendor module.
#
# The counterpart of intel.nix: ./default.nix turns the graphics stack on, this adds amdgpu's
# OpenCL and early KMS. Claims read the evaluated hardware.amdgpu.* options and what they
# expand to, so the initrd really gets amdgpu.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./amd.nix];};
in
  assay.suite "amd" {
    openclEnabled = assay.eq cfg.hardware.amdgpu.opencl.enable true;
    earlyKmsEnabled = assay.eq cfg.hardware.amdgpu.initrd.enable true;
    # What the initrd option expands to: amdgpu loaded before the LUKS prompt.
    amdgpuInInitrd = assay.eq (builtins.elem "amdgpu" cfg.boot.initrd.kernelModules) true;
    # The wrong-vendor guard: nothing from intel.nix comes along.
    noI915InInitrd = assay.eq (builtins.elem "i915" cfg.boot.initrd.kernelModules) false;
  }
