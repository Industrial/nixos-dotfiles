# One minimal x86_64 guest kernel for every compartment (#425).
#
# `make allnoconfig` plus ./config.nix, nothing else: no modules, lockdown in
# confidentiality mode, virtio (PCI and MMIO) for block, console, vsock and pmem,
# erofs, dm-verity, virtio-fs with DAX, and the KSPP hardening that applies. No
# IP stack unless `withInet`. The build fails if Kconfig silently drops any
# requested value, so config.nix is the whole surface.
#
# Outputs: vmlinux (the PVH ELF that cloud-hypervisor and Firecracker boot
# directly), bzImage, the resolved .config, and sizes.txt.
{
  lib,
  stdenv,
  linux_6_18,
  bison,
  flex,
  bc,
  perl,
  elfutils,
  withInet ? false,
}: let
  kernel = linux_6_18;
  cfg = import ./config.nix {inherit lib withInet;};
  checks = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value:
    if value == "n"
    then ''
      if grep -qx 'CONFIG_${name}=.*' .config; then echo "CONFIG_${name} forced on"; bad=1; fi''
    else ''
      grep -qxF '${cfg.render name value}' .config || { echo "CONFIG_${name} wanted ${value}, got: $(grep "CONFIG_${name}[= ]" .config || echo absent)"; bad=1; }'')
  cfg.options);
in
  stdenv.mkDerivation {
    pname = "compartment-guest-kernel" + lib.optionalString withInet "-inet";
    inherit (kernel) version src;

    nativeBuildInputs = [bison flex bc perl elfutils];

    passAsFile = ["fragment"];
    inherit (cfg) fragment;

    makeFlags = ["ARCH=x86_64" "KBUILD_BUILD_USER=nix" "KBUILD_BUILD_HOST=nix" "KBUILD_BUILD_TIMESTAMP=@1"];
    enableParallelBuilding = true;

    configurePhase = ''
      runHook preConfigure
      patchShebangs scripts
      make $makeFlags KCONFIG_ALLCONFIG=$fragmentPath allnoconfig
      bad=0
      ${checks}
      [ $bad = 0 ] || { echo "Kconfig rejected part of config.nix"; exit 1; }
      runHook postConfigure
    '';

    buildFlags = ["vmlinux" "bzImage"];

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp vmlinux $out/vmlinux
      cp arch/x86/boot/bzImage $out/bzImage
      cp .config $out/config
      {
        echo "vmlinux $(stat -c %s vmlinux)"
        echo "bzImage $(stat -c %s arch/x86/boot/bzImage)"
        size vmlinux | tail -1 | awk '{print "text " $1 "\ndata " $2 "\nbss " $3}'
      } > $out/sizes.txt
      runHook postInstall
    '';

    dontStrip = true;
    dontPatchELF = true;

    meta = {
      description = "Minimal, module-less, lockdown guest kernel shared by all compartments";
      license = lib.licenses.gpl2Only;
      platforms = ["x86_64-linux"];
    };
  }
