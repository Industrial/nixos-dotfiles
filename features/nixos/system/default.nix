# This is the system feature. It should at least be included.
{...}: {
  programs.dconf.enable = true;

  boot.initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci" "usbhid" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/e21dfbf4-4d89-4715-818f-d02ca94a6162";
    fsType = "ext4";
  };

  #fileSystems."/data" = {
  #  device = "/dev/disk/by-uuid/8e4e7085-e78b-439b-be0e-2c2423b47062";
  #  fsType = "ext4";
  #  options = ["gid=data"];
  #};

  boot.initrd.luks.devices."luks-84a867b7-d458-474b-9af8-71c23a3dfb95".device = "/dev/disk/by-uuid/84a867b7-d458-474b-9af8-71c23a3dfb95";

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/DA3B-A064";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [];
}
