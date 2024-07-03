{
  inputs,
  settings,
  pkgs,
  ...
}: {
  ansifilter = import ./ansifilter/tests.nix {inherit inputs settings pkgs;};
  appimage-run = import ./appimage-run/tests.nix {inherit inputs settings pkgs;};
  aria2 = import ./aria2/tests.nix {inherit inputs settings pkgs;};
  bat = import ./bat/tests.nix {inherit inputs settings pkgs;};
  btop = import ./btop/tests.nix {inherit inputs settings pkgs;};
  c = import ./c/tests.nix {inherit inputs settings pkgs;};
  cheatsheet = import ./cheatsheet/tests.nix {inherit inputs settings pkgs;};
  cl = import ./cl/tests.nix {inherit inputs settings pkgs;};
  direnv = import ./direnv/tests.nix {inherit inputs settings pkgs;};
  du = import ./du/tests.nix {inherit inputs settings pkgs;};
  dust = import ./dust/tests.nix {inherit inputs settings pkgs;};
  e2fsprogs = import ./e2fsprogs/tests.nix {inherit inputs settings pkgs;};
  eza = import ./eza/tests.nix {inherit inputs settings pkgs;};
  fd = import ./fd/tests.nix {inherit inputs settings pkgs;};
  fh = import ./fh/tests.nix {inherit inputs settings pkgs;};
  fish = import ./fish/tests.nix {inherit inputs settings pkgs;};
  fzf = import ./fzf/tests.nix {inherit inputs settings pkgs;};
  g = import ./g/tests.nix {inherit inputs settings pkgs;};
  gh = import ./gh/tests.nix {inherit inputs settings pkgs;};
  killall = import ./killall/tests.nix {inherit inputs settings pkgs;};
  l = import ./l/tests.nix {inherit inputs settings pkgs;};
  lazygit = import ./lazygit/tests.nix {inherit inputs settings pkgs;};
  ll = import ./ll/tests.nix {inherit inputs settings pkgs;};
  neofetch = import ./neofetch/tests.nix {inherit inputs settings pkgs;};
  p7zip = import ./p7zip/tests.nix {inherit inputs settings pkgs;};
  ranger = import ./ranger/tests.nix {inherit inputs settings pkgs;};
  ripgrep = import ./ripgrep/tests.nix {inherit inputs settings pkgs;};
  starship = import ./starship/tests.nix {inherit inputs settings pkgs;};
  unrar = import ./unrar/tests.nix {inherit inputs settings pkgs;};
  unzip = import ./unzip/tests.nix {inherit inputs settings pkgs;};
  zellij = import ./zellij/tests.nix {inherit inputs settings pkgs;};
}
