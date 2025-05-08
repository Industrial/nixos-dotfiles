{pkgs, ...}: {
  bat = import ./bat/test.nix {inherit pkgs;};
}
