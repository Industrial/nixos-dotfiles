args @ {...}: {
  bitwarden = import ./bitwarden/tests.nix args;
  vaultwarden = import ./vaultwarden/tests.nix args;
  veracrypt = import ./veracrypt/tests.nix args;
  yubikey-manager = import ./yubikey-manager/tests.nix args;
}
