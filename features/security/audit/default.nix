{
  config,
  lib,
  pkgs,
  ...
}: {
  # Comprehensive audit security configuration

  security = {
    # Enable auditd for system auditing
    auditd = {
      enable = true;

      # # Configure audit rules
      # rules = [
      #   # Monitor file access
      #   "-w /etc/passwd -p wa -k identity"
      #   "-w /etc/group -p wa -k identity"
      #   "-w /etc/shadow -p wa -k identity"
      #   "-w /etc/gshadow -p wa -k identity"

      #   # Monitor system calls
      #   "-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change"
      #   "-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change"
      #   "-a always,exit -F arch=b64 -S clock_settime -k time-change"
      #   "-a always,exit -F arch=b32 -S clock_settime -k time-change"
      #   "-w /etc/localtime -p wa -k time-change"

      #   # Monitor user/group changes
      #   "-w /etc/group -p wa -k identity"
      #   "-w /etc/passwd -p wa -k identity"
      #   "-w /etc/gshadow -p wa -k identity"
      #   "-w /etc/shadow -p wa -k identity"
      #   "-w /etc/security/opasswd -p wa -k identity"

      #   # Monitor network configuration
      #   "-w /etc/hosts -p wa -k system-locale"
      #   "-w /etc/network/ -p wa -k system-locale"
      #   "-w /etc/networks/ -p wa -k system-locale"
      #   "-w /etc/protocols -p wa -k system-locale"
      #   "-w /etc/services -p wa -k system-locale"

      #   # Monitor system administration
      #   "-w /etc/sudoers -p wa -k scope"
      #   "-w /etc/sudoers.d/ -p wa -k scope"
      #   "-w /var/log/sudo.log -p wa -k actions"

      #   # Monitor kernel module loading
      #   "-w /sbin/insmod -p x -k modules"
      #   "-w /sbin/rmmod -p x -k modules"
      #   "-w /sbin/modprobe -p x -k modules"
      #   "-a always,exit -F arch=b64 -S init_module -S delete_module -k modules"

      #   # Monitor mount operations
      #   "-w /etc/fstab -p wa -k mounts"
      #   "-w /etc/mtab -p wa -k mounts"
      #   "-w /etc/mount -p wa -k mounts"

      #   # Monitor file deletion
      #   "-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete"
      #   "-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete"
      # ];
    };

    # Enable audit system
    audit = {
      enable = true;
    };
  };
}
