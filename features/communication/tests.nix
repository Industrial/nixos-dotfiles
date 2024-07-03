args @ {
  inputs,
  settings,
  pkgs,
  ...
}: {
  discord = import ./discord/tests.nix args;
}
