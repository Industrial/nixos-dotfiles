# Colocated suite for features/nixos/boot/default.nix (ADR-0007).
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
  # The same module in an evaluation that has no lanzaboote input (null overrides the one
  # nixos.nix resolves from flake.lock).
  evalNoLanza = extra:
    nixos.eval {
      modules = [./default.nix esp] ++ extra;
      inputs.lanzaboote = null;
    };
  missing = expected: lib.subtractLists default.boot.kernelParams expected;

  default = eval [];
  inherit (default.boot.kernel) sysctl;
  tpm = eval [
    {
      features.hardening.tpm2Unlock.enable = true;
      boot.initrd.luks.devices.cryptroot.device = "/dev/null";
    }
  ];
  sbOn = {features.hardening.secureBoot.enable = true;};
  sb = eval [sbOn];
  sbNoLanza = evalNoLanza [sbOn];
  sbMeasured = eval [sbOn {boot.lanzaboote.extraEfiSysMountPoints = ["/boot2"];}];
  # What a host evaluates when the option is off: the lanzaboote module is there, inert.
  noLanzaDefault = evalNoLanza [];
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

    # Memory sysctls are owned by features/performance/memory as real sysctls; the inert
    # vm.* command-line copies that used to sit here must not come back.
    noMemorySysctlOnCmdline =
      assay.eq (builtins.filter (lib.hasPrefix "vm.") default.boot.kernelParams) [];

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

    # Deliberately NOT set (ADR-0007): these would break gaming, rootless Docker, debugging
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
      assay.eq (builtins.any (a: builtins.match ".*needs the lanzaboote NixOS module.*" a.message != null) (failed sbNoLanza)) true;
    # Without the input the option still exists, so an off host evaluates the same.
    noInputStillEvaluates = assay.eq (failed noLanzaDefault) [];

    # GH-184: the flake input's module is imported on every host, and inert while off: the
    # Python systemd-boot installer stays the bootloader installer.
    lanzabooteModuleImported = assay.eq (default ? boot && default.boot ? lanzaboote) true;
    lanzabooteOffByDefault = assay.eq default.boot.lanzaboote.enable false;
    noExternalInstallerByDefault = assay.eq default.boot.loader.external.enable false;

    # Secure Boot on: lzbt replaces systemd-boot's installer, cleanly.
    secureBootEvaluatesCleanly = assay.eq (failed sb) [];
    secureBootEnablesLanzaboote = assay.eq sb.boot.lanzaboote.enable true;
    secureBootUsesExternalInstaller = assay.eq sb.boot.loader.external.enable true;
    # The regression this suite missed: `{boot.loader…} // {boot.lanzaboote…}` dropped the
    # left-hand `boot`, leaving systemd-boot on next to lanzaboote (a conflicting definition).
    secureBootTurnsSystemdBootOff = assay.eq sb.boot.loader.systemd-boot.enable false;
    secureBootEditorOff = assay.eq [sb.boot.loader.systemd-boot.editor sb.boot.lanzaboote.settings.editor] [false false];
    secureBootPkiBundle = assay.eq sb.boot.lanzaboote.pkiBundle "/var/lib/sbctl";
    # Same generation limit as systemd-boot, so the 511M ESP holds what it holds today.
    secureBootKeepsTenGenerations = assay.eq sb.boot.lanzaboote.configurationLimit 10;
    # Keys are created by hand (runbook), never generated or enrolled behind the operator's back.
    secureBootNoAutoKeys = assay.eq [sb.boot.lanzaboote.autoGenerateKeys.enable sb.boot.lanzaboote.autoEnrollKeys.enable sb.boot.lanzaboote.allowUnsigned] [false false false];
    # Our hook, not upstream's: upstream only sees system-*-link and defaults to the highest
    # version, which on drakkar (comin's system-profiles/comin, stale system-493) boots the
    # stale generation.
    secureBootInstallsEveryProfile =
      assay.eq (builtins.match ".*-lzbt-all-profiles/bin/lzbt-all-profiles" sb.boot.loader.external.installHook != null) true;
    # And it is what switch-to-configuration runs.
    secureBootHookIsTheInstaller =
      assay.eq sb.system.build.installBootLoader sb.boot.loader.external.installHook;
    # The hook ports neither of these upstream extras: on, they must refuse to evaluate.
    secureBootRefusesUnportedExtras = assay.eq (builtins.any (a: builtins.match ".*supports neither extraEfiSysMountPoints nor measuredBoot.*" a.message != null) (failed sbMeasured)) true;
    secureBootShipsSbctl = assay.eq (nixos.hasPackage sb "sbctl") true;
  }
