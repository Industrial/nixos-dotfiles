let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "boot_test";
    actual = feature.boot.loader.systemd-boot.enable;
    expected = true;
  }
  {
    name = "boot_test";
    actual = feature.boot.loader.efi.canTouchEfiVariables;
    expected = true;
  }
  {
    name = "boot_test";
    actual = feature.boot.loader.efi.efiSysMountPoint;
    expected = "/boot/efi";
  }
  {
    name = "boot_test";
    actual = feature.boot.initrd.secrets;
    expected = {
      "/crypto_keyfile.bin" = null;
    };
  }
]
