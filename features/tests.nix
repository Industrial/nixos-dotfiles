{
  inputs,
  settings,
  pkgs,
  ...
}: {
  cli = import ./cli/tests.nix {inherit inputs settings pkgs;};
}
