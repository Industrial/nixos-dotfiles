args @ {...}: {
  veracrypt = import ./veracrypt/tests.nix args;
  yubikey-manager = import ./yubikey-manager/tests.nix args;
}
