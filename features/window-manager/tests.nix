args @ {
  inputs,
  settings,
  pkgs,
  ...
}: {
  alacritty = import ./alacritty/tests.nix args;
  dwm = import ./dwm/tests.nix args;
  hyper = import ./hyper/tests.nix args;
  slock = import ./slock/tests.nix args;
  stylix = import ./stylix/tests.nix args;
  xfce = import ./xfce/tests.nix args;
  xmonad = import ./xmonad/tests.nix args;
}
