args @ {
  inputs,
  settings,
  pkgs,
  ...
}: {
  monero = import ./monero/tests.nix args;
}
