args @ {
  inputs,
  settings,
  pkgs,
  ...
}: {
  ansifilter = import ./ansifilter/tests.nix args;
  appimage-run = import ./appimage-run/tests.nix args;
  aria2 = import ./aria2/tests.nix args;
  bat = import ./bat/tests.nix args;
  btop = import ./btop/tests.nix args;
  c = import ./c/tests.nix args;
  cheatsheet = import ./cheatsheet/tests.nix args;
  cl = import ./cl/tests.nix args;
  direnv = import ./direnv/tests.nix args;
  du = import ./du/tests.nix args;
  dust = import ./dust/tests.nix args;
  e2fsprogs = import ./e2fsprogs/tests.nix args;
  eza = import ./eza/tests.nix args;
  fd = import ./fd/tests.nix args;
  fh = import ./fh/tests.nix args;
  fish = import ./fish/tests.nix args;
  fzf = import ./fzf/tests.nix args;
  g = import ./g/tests.nix args;
  gh = import ./gh/tests.nix args;
  killall = import ./killall/tests.nix args;
  l = import ./l/tests.nix args;
  lazygit = import ./lazygit/tests.nix args;
  ll = import ./ll/tests.nix args;
  neofetch = import ./neofetch/tests.nix args;
  nushell = import ./nushell/tests.nix args;
  p7zip = import ./p7zip/tests.nix args;
  ranger = import ./ranger/tests.nix args;
  ripgrep = import ./ripgrep/tests.nix args;
  starship = import ./starship/tests.nix args;
  unrar = import ./unrar/tests.nix args;
  unzip = import ./unzip/tests.nix args;
  zellij = import ./zellij/tests.nix args;
}
