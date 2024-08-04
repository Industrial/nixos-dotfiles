args @ {...}: {
  alacritty = import ./alacritty/tests.nix args;
  xfce = import ./xfce/tests.nix args;
}
