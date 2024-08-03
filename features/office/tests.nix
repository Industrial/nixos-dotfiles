args @ {...}: {
  cryptpad = import ./cryptpad/tests.nix args;
  obsidian = import ./obsidian/tests.nix args;
}
