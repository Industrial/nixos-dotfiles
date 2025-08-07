{
  config,
  lib,
  pkgs,
  ...
}: {
  # Comprehensive boot configuration with security and performance optimizations

  boot = {
    # Enable secure boot
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi = {
        canTouchEfiVariables = true;
      };
    };

    # Configure kernel parameters for security and performance
    kernelParams = [
      # Security kernel parameters
      "fs.suid_dumpable=0"
      "kernel.randomize_va_space=2"
      "kernel.sysrq=0"

      # Network security parameters
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

      # IPv6 security parameters
      "net.ipv6.conf.all.accept_redirects=0"
      "net.ipv6.conf.default.accept_redirects=0"
      "net.ipv6.conf.all.accept_ra=0"
      "net.ipv6.conf.default.accept_ra=0"

      # Disable ICMP redirects
      "net.ipv4.conf.all.accept_source_route=0"
      "net.ipv4.conf.default.accept_source_route=0"
      "net.ipv6.conf.all.accept_source_route=0"
      "net.ipv6.conf.default.accept_source_route=0"

      # Performance kernel parameters
      "transparent_hugepage=always"
      "elevator=deadline"
      "cpufreq.default_governor=performance"

      # Memory management optimization
      "vm.swappiness=10"
      "vm.dirty_ratio=15"
      "vm.dirty_background_ratio=5"

      # Network performance optimization
      "net.core.rmem_max=16777216"
      "net.core.wmem_max=16777216"
      # "net.ipv4.tcp_rmem=4096 87380 16777216"
      # "net.ipv4.tcp_wmem=4096 65536 16777216"
      "net.core.netdev_max_backlog=5000"
      "net.ipv4.tcp_congestion_control=bbr"

      # File system performance optimization
      "fs.file-max=2097152"
      "fs.inotify.max_user_watches=524288"
    ];

    # Configure initrd for performance and security
    initrd = {
      # Enable early microcode loading
      systemd.enable = true;

      # Optimize initrd size
      verbose = false;
    };
  };
}
