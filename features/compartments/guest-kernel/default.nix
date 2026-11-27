# The one guest kernel every compartment boots (#425): ./package.nix.
#
# Off by default. When on, the host carries the kernel at a stable path,
# /etc/compartments/guest-kernel/{vmlinux,bzImage,config,sizes.txt}, for its VMMs
# (cloud-hypervisor, Firecracker) to share read-only. Nothing else changes, and
# the feature declares no options, so a host with it off evaluates to the same
# toplevel as before. Build it alone with `nix build .#compartment-guest-kernel`.
#
# Measured on muninn (docs/research/compartments/05-baseline-muninn.md).
{pkgs, ...}: {
  environment.etc."compartments/guest-kernel".source = pkgs.callPackage ./package.nix {};
}
