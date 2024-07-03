args @ {
  inputs,
  settings,
  pkgs,
  ...
}: {
  zsa-keyboard = import ./zsa-keyboard/tests.nix args;
}
