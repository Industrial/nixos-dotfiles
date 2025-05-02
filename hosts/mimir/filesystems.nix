{config, lib, ...}: {
  # Enable impermanence
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.emergencyAccess = true;

  # Configure impermanence
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      # System directories
      "/etc/nixos"
      "/etc/NetworkManager/system-connections"
      "/var/lib"
      "/var/log"
      "/var/cache"
      "/var/spool"
      
      # User directories
      "/home"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  # Ensure persist directory is available at boot
  fileSystems."/persist".neededForBoot = true;

  # Configure Btrfs
  boot.supportedFilesystems = ["btrfs"];
  
  # Enable Btrfs scrub for data integrity
  services.btrfs.autoScrub.enable = true;
  services.btrfs.autoScrub.fileSystems = [ "/data" ];
  services.btrfs.autoScrub.interval = "monthly";

  # Boot configuration
  boot = {
    initrd = {
      availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod"];
      kernelModules = [];

      luks = {
        devices = {
          "cryptroot" = {
            device = "/dev/nvme0n1p2";
          };
          "cryptdata-a" = {
            device = "/dev/sda1";
          };
          "cryptdata-b" = {
            device = "/dev/sdb1";
          };
          "cryptdata-c" = {
            device = "/dev/sdc1";
          };
          "cryptdata-d" = {
            device = "/dev/sdd1";
          };
        };
      };
    };

    kernelModules = [
      "kvm-amd"
    ];

    # Resume from swap (hibernation)
    resumeDevice = "/dev/mapper/cryptroot";
  };
} 
