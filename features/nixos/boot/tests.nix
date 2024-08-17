args @ {...}: let
  feature = import ./default.nix args;
in {
  test_boot_loader_systemd-boot_enable = {
    expr = feature.boot.loader.systemd-boot.enable;
    expected = true;
  };
  # test_boot_loader_efi_canTouchEfiVariables = {
  #   expr = feature.boot.loader.efi.canTouchEfiVariables;
  #   expected = true;
  # };
  # test_boot_initrd_secrets___crypto_keyfile_bin = {
  #   expr = feature.boot.initrd.secrets."/crypto_keyfile.bin";
  #   expected = null;
  # };
}
