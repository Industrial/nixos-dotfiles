let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.boot.loader.systemd-boot.enable;
    expected = true;
  }
  {
    actual = feature.boot.loader.efi.canTouchEfiVariables;
    expected = true;
  }
  {
    actual = feature.boot.loader.efi.efiSysMountPoint;
    expected = "/boot/efi";
  }
  {
    actual = feature.boot.initrd.secrets;
    expected = {
      "/crypto_keyfile.bin" = null;
    };
  }
]
