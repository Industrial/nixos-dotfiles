# lsusb - List USB devices
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    usbutils
  ];
}
