{pkgs, ...}: {
  bat = import ./bat/bat.test.nix {inherit pkgs;};
}
