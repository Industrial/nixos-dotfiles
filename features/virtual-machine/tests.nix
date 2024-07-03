args @ {
  inputs,
  settings,
  pkgs,
  ...
}: {
  base = import ./base/tests.nix args;
  kubernetes = import ./kubernetes/tests.nix args;
  microvm = import ./microvm/tests.nix args;
  ssh = import ./ssh/tests.nix args;
}
