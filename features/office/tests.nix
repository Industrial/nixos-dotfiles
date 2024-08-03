args @ {...}: {
  cryptpad = import ./cryptpad/tests.nix args;
  evince = import ./evince/tests.nix args;
  obsidian = import ./obsidian/tests.nix args;
}
