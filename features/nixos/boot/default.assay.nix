# Colocated suite for features/nixos/boot/default.nix (ADR-0006).
#
# Evaluates the module in a real NixOS system, so the sysctls are read from the merged
# boot.kernel.sysctl, the same attrset nixpkgs renders into /etc/sysctl.d/60-nixos.conf.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  # The assay base host has no ESP. systemd-boot needs one mounted to evaluate.
  esp = {
    fileSystems."/boot" = {
      device = "/dev/null";
      fsType = "vfat";
    };
  };
  eval = extra: nixos.eval {modules = [./default.nix esp] ++ extra;};
  missing = expected: lib.subtractLists default.boot.kernelParams expected;

  default = eval [];
  sysctl = default.boot.kernel.sysctl;
  tpm = eval [
    {
      features.hardening.tpm2Unlock.enable = true;
      boot.initrd.luks.devices.cryptroot.device = "/dev/null";
    }
  ];
  sb = eval [{features.hardening.secureBoot.enable = true;}];
  failed = config: builtins.filter (a: !a.assertion) config.assertions;

  isSysctlName = p: builtins.match "(kernel|net|vm|fs)\\.[a-z0-9_.]+=.*" p != null;
in
  assay.suite "boot" {
    systemdBoot = assay.eq default.boot.loader.systemd-boot.enable true;
    keepsTenGenerations = assay.eq default.boot.loader.systemd-boot.configurationLimit 10;
    mayWriteEfiVariables = assay.eq default.boot.loader.efi.canTouchEfiVariables true;
    # 26.11+ default, set explicitly: a pool last imported elsewhere is never force-imported.
    zfsNeverForceImportsRoot = assay.eq default.boot.zfs.forceImportRoot false;
    # Real kernel parameters keep their place on the command line.
    performanceParamsPresent = assay.eq (missing ["transparent_hugepage=always"]) [];

    # The bug this file had: security sysctls as kernel command-line strings, which the
    # kernel never applies. None of the security ones may come back there.
    noSecuritySysctlOnCmdline = assay.eq (builtins.filter (p:
      isSysctlName p
      && builtins.match ".*(redirect|source_route|rp_filter|martians|suid_dumpable|sysrq|randomize_va_space|accept_ra).*" p != null)
    default.boot.kernelParams) [];

    dmesgRestricted = assay.eq sysctl."kernel.dmesg_restrict" 1;
    unprivBpfOff = assay.eq sysctl."kernel.unprivileged_bpf_disabled" 1;
    bpfJitHardened = assay.eq sysctl."net.core.bpf_jit_harden" 2;
    noIcmpRedirects = assay.eq [
      sysctl."net.ipv4.conf.all.accept_redirects"
      sysctl."net.ipv4.conf.default.accept_redirects"
      sysctl."net.ipv6.conf.all.accept_redirects"
      sysctl."net.ipv6.conf.default.accept_redirects"
      sysctl."net.ipv4.conf.all.secure_redirects"
      sysctl."net.ipv4.conf.all.send_redirects"
    ] [0 0 0 0 0 0];
    noSourceRouting = assay.eq [
      sysctl."net.ipv4.conf.all.accept_source_route"
      sysctl."net.ipv6.conf.all.accept_source_route"
    ] [0 0];
    logsMartians = assay.eq sysctl."net.ipv4.conf.all.log_martians" 1;
    rfc1337 = assay.eq sysctl."net.ipv4.tcp_rfc1337" 1;

    # STIG-owned keys stay with the STIG modules (ADR-0003). V-268160 requires exactly 1, and
    # nixpkgs' own mkDefault already gives that.
    kptrRestrictIsNixpkgsDefault = assay.eq sysctl."kernel.kptr_restrict" 1;

    # Deliberately NOT set (ADR-0006): these would break gaming, rootless Docker, debugging
    # or Tailscale routing.
    userNamespacesUntouched = assay.eq (sysctl ? "kernel.unprivileged_userns_clone") false;
    ptraceScopeUntouched = assay.eq (sysctl ? "kernel.yama.ptrace_scope") false;
    rpFilterLeftToFirewall = assay.eq (sysctl ? "net.ipv4.conf.all.rp_filter") false;
    ipv6RaUntouched = assay.eq (sysctl ? "net.ipv6.conf.all.accept_ra") false;

    blacklistsDccp = assay.eq (builtins.elem "dccp" default.boot.blacklistedKernelModules) true;
    blacklistsTipc = assay.eq (builtins.elem "tipc" default.boot.blacklistedKernelModules) true;

    # The boot editor stays on while Secure Boot is off. It is the locked-root recovery path.
    editorKeptForRecovery = assay.eq default.boot.loader.systemd-boot.editor true;

    # Physical-access options: off by default, and inert while off.
    secureBootOff = assay.eq default.features.hardening.secureBoot.enable false;
    tpm2UnlockOff = assay.eq default.features.hardening.tpm2Unlock.enable false;
    noTpmStackByDefault = assay.eq default.security.tpm2.enable false;
    defaultEvaluatesCleanly = assay.eq (failed default) [];

    # TPM2 on: systemd initrd with the TPM2 token and crypttab option for cryptroot.
    tpmEnablesTpm2Stack = assay.eq tpm.security.tpm2.enable true;
    tpmInitrdToken = assay.eq tpm.boot.initrd.systemd.tpm2.enable true;
    tpmCrypttab =
      assay.eq tpm.boot.initrd.luks.devices.cryptroot.crypttabExtraOpts ["tpm2-device=auto"];

    # Secure Boot on without the lanzaboote module: refuse to evaluate, never half-apply.
    secureBootNeedsLanzaboote =
      assay.eq (builtins.any (a: builtins.match ".*needs the lanzaboote NixOS module.*" a.message != null) (failed sb)) true;
  }
