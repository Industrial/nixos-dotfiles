args @ {...}: {
  master = import ./master/tests.nix args;
  node = import ./node/tests.nix args;
}
