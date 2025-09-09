{
  config,
  lib,
  pkgs,
  ...
}: {
  # Kernel security configuration

  security = {
    # Configure unprivileged user namespaces
    unprivilegedUsernsClone = true;

    # Configure protect kernel modules
    protectKernelImage = true;

    # Configure lock kernel modules
    lockKernelModules = true;

    # # Configure kernel lockdown
    # kernelLockdown = "integrity";

    # # Configure secure boot
    # secureBoot = {
    #   enable = true;
    # };

    # # Configure virtual memory protection
    # virtualisation = {
    #   protectHostname = true;
    # };

    # Advanced security settings (commented out)
    # kernelLockdown = "confidentiality";
    # unprivilegedUsernsClone = false; # Disable for maximum security
  };

  # Configure users for security
  users = {
    # Configure default user security
    defaultUserShell = pkgs.bash;
  };

  # Advanced kernel sysctl configuration (commented out)
  # boot = {
  #   kernel.sysctl = {
  #     # Disable kernel debugging
  #     "kernel.kptr_restrict" = 2;
  #     "kernel.dmesg_restrict" = 1;
  #     "kernel.perf_event_paranoid" = 3;
  #     "kernel.yama.ptrace_scope" = 1;
  #     "kernel.unprivileged_bpf_disabled" = 1;
  #     "net.core.bpf_jit_harden" = 2;
  #   };
  # };
}
