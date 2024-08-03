args @ {...}: {
  apparmor = import ./apparmor/tests.nix args;
  yubikey = import ./yubikey/tests.nix args;
}
