args @ {...}: {
  apparmor = import ./apparmor/tests.nix args;
  clamav = import ./clamav/tests.nix args;
  yubikey = import ./yubikey/tests.nix args;
}
