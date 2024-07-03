args @ {
  inputs,
  settings,
  pkgs,
  ...
}: {
  settings = import ./settings/tests.nix args;
}
