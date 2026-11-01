# Intel integrated graphics (Gen12 "Xe" and newer — Alder Lake-N, Raptor Lake, Meteor Lake).
#
# The counterpart to ./amd.nix: ./default.nix turns the graphics stack on for every host, and
# this module adds the vendor-specific userspace that stack needs. Importing the wrong vendor
# module is not fatal, but it loads a GPU driver into the initrd that will never bind and leaves
# VA-API and OpenCL unaccelerated, so a host imports exactly one of amd.nix / intel.nix.
{pkgs, ...}: {
  boot = {
    initrd = {
      # Early KMS: the console and the LUKS passphrase prompt come up at native resolution
      # instead of the EFI framebuffer, which on a HiDPI tablet panel is the difference between
      # a readable prompt and a postage stamp.
      kernelModules = ["i915"];
    };
  };

  hardware = {
    graphics = {
      extraPackages = with pkgs; [
        # VA-API: hardware video decode/encode via the iHD driver (Gen9+).
        intel-media-driver
        # oneVPL runtime — the supported QuickSync path on Gen12+.
        vpl-gpu-rt
        # OpenCL, matching what amd.nix enables for amdgpu.
        intel-compute-runtime
      ];
    };
  };

  environment = {
    sessionVariables = {
      # Without this, libva picks the legacy i965 driver, which has no Gen12 support.
      LIBVA_DRIVER_NAME = "iHD";
    };
  };
}
