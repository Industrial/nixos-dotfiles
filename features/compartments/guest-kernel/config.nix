# The guest kernel's Kconfig, as the only input on top of `make allnoconfig`.
#
# Everything not named here is off: allnoconfig answers "no" to every prompt, and
# EXPERT = yes exposes the prompts that otherwise hide behind a default of "yes"
# (io_uring, BPF, AIO, kallsyms, ...), so they are off too. package.nix fails the
# build if Kconfig drops or changes any value below (an unmet dependency), so this
# file is the kernel's complete, checked surface.
#
# `withInet` adds IPv4 and virtio-net. Without it the only socket families are
# AF_VSOCK and AF_UNIX: CONFIG_NET is on because vsock is a socket family.
{
  lib,
  withInet ? false,
}: let
  y = "y";
  n = "n";

  platform = {
    "64BIT" = y;
    EXPERT = y;
    SMP = y;
    NR_CPUS = "64";
    HYPERVISOR_GUEST = y;
    PARAVIRT = y;
    KVM_GUEST = y;
    # cloud-hypervisor and Firecracker boot the uncompressed vmlinux through the PVH
    # entry point, which skips the decompressor.
    PVH = y;
    # cloud-hypervisor describes CPUs, the PCI host bridge and power-off through ACPI.
    ACPI = y;
    PCI = y;
    PCI_MSI = y;
    NO_HZ_IDLE = y;
    HIGH_RES_TIMERS = y;
    PRINTK = y;
    BUG = y;
    TTY = y;
    # Early diagnostics only: the measured boots pass `quiet` and no serial device.
    SERIAL_8250 = y;
    SERIAL_8250_CONSOLE = y;
    BLK_DEV_INITRD = y;
    BINFMT_ELF = y;
    DEVTMPFS = y;
    TMPFS = y;
    PROC_FS = y;
    SYSFS = y;
    MULTIUSER = y;
    # What a static Rust/tokio program asks of the kernel.
    FUTEX = y;
    EPOLL = y;
    EVENTFD = y;
    SIGNALFD = y;
    TIMERFD = y;
    SHMEM = y;
    POSIX_TIMERS = y;
    ADVISE_SYSCALLS = y;
    MEMBARRIER = y;
    # Kill the VM, never limp on: PID 1 exiting or an oops reboots, which ends the VMM.
    PANIC_ON_OOPS = y;
    PANIC_TIMEOUT = "-1";
  };

  modulesOff = {
    MODULES = n;
  };

  virtio = {
    VIRTIO_MENU = y;
    VIRTIO_PCI = y;
    VIRTIO_MMIO = y;
    # Firecracker passes its MMIO devices on the command line.
    VIRTIO_MMIO_CMDLINE_DEVICES = y;
    BLOCK = y;
    BLK_DEV = y;
    VIRTIO_BLK = y;
    VIRTIO_CONSOLE = y;
    VSOCKETS = y;
    VIRTIO_VSOCKETS = y;
    # virtio-pmem: a host file mapped straight into the guest, so content-identical
    # read-only blobs are one host page-cache copy for every guest (report 05).
    LIBNVDIMM = y;
    BLK_DEV_PMEM = y;
    VIRTIO_PMEM = y;
    # Without it the virtio-pmem namespace fails to probe (-ENXIO) and no /dev/pmem0 appears.
    NVDIMM_PFN = y;
    NVDIMM_DAX = y;
  };

  storage = {
    MISC_FILESYSTEMS = y;
    EROFS_FS = y;
    MD = y;
    BLK_DEV_DM = y;
    DM_VERITY = y;
    # dm-mod.create= on the command line: a verity root with no userspace in the initrd.
    DM_INIT = y;
    CRYPTO = y;
    CRYPTO_SHA256 = y;
    # virtio-fs with a DAX window.
    FUSE_FS = y;
    VIRTIO_FS = y;
    SPARSEMEM_VMEMMAP = y;
    MIGRATION = y;
    MEMORY_HOTPLUG = y;
    MEMORY_HOTREMOVE = y;
    ZONE_DEVICE = y;
    FS_DAX = y;
    FUSE_DAX = y;
  };

  network =
    {
      NET = y;
      UNIX = y;
    }
    // (
      if withInet
      then {
        INET = y;
        NETDEVICES = y;
        NET_CORE = y;
        VIRTIO_NET = y;
      }
      else {
        INET = n;
        NETDEVICES = n;
      }
    );

  # Lockdown in confidentiality mode, from the first instruction.
  lockdown = {
    SECURITY = y;
    SECURITY_LOCKDOWN_LSM = y;
    SECURITY_LOCKDOWN_LSM_EARLY = y;
    LOCK_DOWN_KERNEL_FORCE_CONFIDENTIALITY = y;
    SECURITY_YAMA = y;
    LSM = ''"lockdown,yama"'';
  };

  # KSPP recommended settings (kernsec.org/wiki/index.php/Kernel_Self_Protection_Project/Recommended_Settings)
  # that apply to a module-less x86_64 guest. Not taken: the GCC-plugin options
  # (RANDSTRUCT, STACKLEAK, LATENT_ENTROPY), which need a plugin-enabled compiler.
  kspp = {
    RELOCATABLE = y;
    RANDOMIZE_BASE = y;
    RANDOMIZE_MEMORY = y;
    STRICT_KERNEL_RWX = y;
    DEBUG_WX = y;
    VMAP_STACK = y;
    STACKPROTECTOR = y;
    STACKPROTECTOR_STRONG = y;
    HARDENED_USERCOPY = y;
    FORTIFY_SOURCE = y;
    INIT_ON_ALLOC_DEFAULT_ON = y;
    INIT_ON_FREE_DEFAULT_ON = y;
    INIT_STACK_ALL_ZERO = y;
    ZERO_CALL_USED_REGS = y;
    SLAB_FREELIST_RANDOM = y;
    SLAB_FREELIST_HARDENED = y;
    SHUFFLE_PAGE_ALLOCATOR = y;
    RANDOM_KMALLOC_CACHES = y;
    LIST_HARDENED = y;
    BUG_ON_DATA_CORRUPTION = y;
    SCHED_STACK_END_CHECK = y;
    PAGE_TABLE_CHECK = y;
    PAGE_TABLE_CHECK_ENFORCED = y;
    SECCOMP = y;
    SECCOMP_FILTER = y;
    STATIC_USERMODEHELPER = y;
    STATIC_USERMODEHELPER_PATH = ''""'';
    LEGACY_VSYSCALL_NONE = y;
    X86_VSYSCALL_EMULATION = n;
    MODIFY_LDT_SYSCALL = n;
    IA32_EMULATION = n;
    X86_X32_ABI = n;
    COMPAT_BRK = n;
    PROC_KCORE = n;
    DEVMEM = n;
    KEXEC = n;
    KEXEC_FILE = n;
    HIBERNATION = n;
    BPF_SYSCALL = n;
    USERFAULTFD = n;
    IO_URING = n;
    KALLSYMS = n;
    LDISC_AUTOLOAD = n;
    SYSFS_SYSCALL = n;
    CPU_MITIGATIONS = y;
    MITIGATION_PAGE_TABLE_ISOLATION = y;
    MITIGATION_RETPOLINE = y;
  };
in rec {
  options = platform // modulesOff // virtio // storage // network // lockdown // kspp;

  # The KCONFIG_ALLCONFIG fragment: `CONFIG_X=y`, `# CONFIG_X is not set`, `CONFIG_X=v`.
  render = name: value:
    if value == n
    then "# CONFIG_${name} is not set"
    else "CONFIG_${name}=${value}";

  fragment = lib.concatStringsSep "\n" (lib.mapAttrsToList render options) + "\n";
}
