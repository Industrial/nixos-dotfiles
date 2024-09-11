args @ {...}: {
  discord = import ./discord/tests.nix args;
  fractal = import ./fractal/tests.nix args;
}
