# Assay: boot loader and kernel command line.
#
# Claims read the evaluated boot.* options. The kernel parameters are compared as "which of
# the expected entries are missing", so a failure names the parameter that went away.
#
# NOTE, recorded rather than asserted away: most of the "security" entries below are sysctl
# keys (kernel.sysrq, net.ipv4.conf.*), and a bare sysctl key on the kernel command line is
# not a sysctl -- the kernel only applies them with a `sysctl.` prefix (5.8+), and otherwise
# hands them to init as unknown arguments. These claims pin what the module sets; they do not
# show the hardening takes effect. boot.kernel.sysctl is where it would.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  params = cfg.boot.kernelParams;
  missing = expected: lib.subtractLists params expected;
in
  assay.suite "boot" {
    usesSystemdBoot = assay.eq cfg.boot.loader.systemd-boot.enable true;
    keepsTenGenerations = assay.eq cfg.boot.loader.systemd-boot.configurationLimit 10;
    mayWriteEfiVariables = assay.eq cfg.boot.loader.efi.canTouchEfiVariables true;
    # The module leaves `editor = false` commented out, so the systemd-boot editor stays at
    # NixOS's default (on): anyone at the console can edit the kernel command line. Pinned
    # so that turning it off is a deliberate, visible change here.
    bootEditorLeftAtDefault = assay.eq cfg.boot.loader.systemd-boot.editor true;

    # 26.11+ default, set explicitly: a pool last imported elsewhere is never force-imported.
    zfsNeverForceImportsRoot = assay.eq cfg.boot.zfs.forceImportRoot false;

    securityParamsPresent = assay.eq (missing [
      "fs.suid_dumpable=0"
      "kernel.randomize_va_space=2"
      "kernel.sysrq=0"
    ]) [];
    ipv4RedirectAndSpoofParamsPresent = assay.eq (missing [
      "net.ipv4.conf.all.accept_redirects=0"
      "net.ipv4.conf.default.accept_redirects=0"
      "net.ipv4.conf.all.secure_redirects=0"
      "net.ipv4.conf.default.secure_redirects=0"
      "net.ipv4.conf.all.send_redirects=0"
      "net.ipv4.conf.default.send_redirects=0"
      "net.ipv4.conf.all.rp_filter=1"
      "net.ipv4.conf.default.rp_filter=1"
      "net.ipv4.conf.all.log_martians=1"
      "net.ipv4.conf.default.log_martians=1"
      "net.ipv4.conf.all.accept_source_route=0"
      "net.ipv4.conf.default.accept_source_route=0"
    ]) [];
    ipv6RedirectAndRaParamsPresent = assay.eq (missing [
      "net.ipv6.conf.all.accept_redirects=0"
      "net.ipv6.conf.default.accept_redirects=0"
      "net.ipv6.conf.all.accept_ra=0"
      "net.ipv6.conf.default.accept_ra=0"
      "net.ipv6.conf.all.accept_source_route=0"
      "net.ipv6.conf.default.accept_source_route=0"
    ]) [];
    performanceParamsPresent = assay.eq (missing [
      "transparent_hugepage=always"
      "cpufreq.default_governor=performance"
      "net.ipv4.tcp_congestion_control=bbr"
      "vm.swappiness=10"
      "fs.inotify.max_user_watches=524288"
    ]) [];
    # Real sysctls are set nowhere by this module (see the NOTE above).
    setsNoSysctls = assay.eq cfg.boot.kernel.sysctl nixos.baseline.boot.kernel.sysctl;
  }
