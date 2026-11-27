# Colocated suite for features/compartments/guest-kernel/config.nix (#425).
#
# The build (package.nix) fails if Kconfig drops a requested value; this suite pins what
# is requested, so a change to the kernel's surface shows up here.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = import ./config.nix {inherit lib;};
  base = cfg.options;
  inet =
    (import ./config.nix {
      inherit lib;
      withInet = true;
    }).options;
  on = o: name: (o.${name} or "n") == "y";
in
  assay.suite "guest-kernel-config" {
    noModules = assay.eq base.MODULES "n";
    lockdownConfidentialityFromBoot =
      assay.eq (map (on base) ["SECURITY_LOCKDOWN_LSM" "SECURITY_LOCKDOWN_LSM_EARLY" "LOCK_DOWN_KERNEL_FORCE_CONFIDENTIALITY"]) [true true true];
    lsmOrder = assay.eq base.LSM ''"lockdown,yama"'';
    kaslr = assay.eq (map (on base) ["RELOCATABLE" "RANDOMIZE_BASE" "RANDOMIZE_MEMORY"]) [true true true];

    virtioTransportsAndDevices =
      assay.eq (map (on base) ["VIRTIO_PCI" "VIRTIO_MMIO" "VIRTIO_BLK" "VIRTIO_CONSOLE" "VIRTIO_VSOCKETS" "VIRTIO_PMEM" "VIRTIO_FS"]) [true true true true true true true];
    storage = assay.eq (map (on base) ["EROFS_FS" "DM_VERITY" "DM_INIT" "FS_DAX" "FUSE_DAX"]) [true true true true true];
    # Without NVDIMM_PFN the virtio-pmem namespace does not probe (report 05, §5.2).
    pmemNamespacesProbe = assay.eq (map (on base) ["NVDIMM_PFN" "NVDIMM_DAX"]) [true true];

    # vsock is a socket family, so NET is on, but there is no IP stack and no NIC.
    noIpByDefault = assay.eq [base.NET base.INET base.NETDEVICES (base ? VIRTIO_NET)] ["y" "n" "n" false];
    inetOnlyWithTheFlag = assay.eq [inet.INET inet.VIRTIO_NET] ["y" "y"];

    # Attack surface KSPP asks to remove.
    ksppOff =
      assay.eq (lib.filter (n: base.${n} != "n") ["IO_URING" "BPF_SYSCALL" "USERFAULTFD" "KEXEC" "DEVMEM" "PROC_KCORE" "MODIFY_LDT_SYSCALL" "IA32_EMULATION" "KALLSYMS" "HIBERNATION"]) [];
    ksppOn =
      assay.eq (lib.filter (n: base.${n} != "y") ["STACKPROTECTOR_STRONG" "HARDENED_USERCOPY" "FORTIFY_SOURCE" "INIT_ON_ALLOC_DEFAULT_ON" "INIT_ON_FREE_DEFAULT_ON" "INIT_STACK_ALL_ZERO" "SLAB_FREELIST_HARDENED" "SHUFFLE_PAGE_ALLOCATOR" "STRICT_KERNEL_RWX" "VMAP_STACK" "LEGACY_VSYSCALL_NONE" "PAGE_TABLE_CHECK_ENFORCED"]) [];

    # The fragment is what reaches `make allnoconfig`.
    fragmentRendersOffAsNotSet = assay.eq (lib.hasInfix "# CONFIG_MODULES is not set\n" cfg.fragment) true;
    fragmentRendersValues = assay.eq (lib.hasInfix "CONFIG_PANIC_TIMEOUT=-1\n" cfg.fragment) true;
  }
