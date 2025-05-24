{pkgs, ...}: {
  _assert = import ./assert.test.nix {inherit pkgs;};
  settings = import ./settings.test.nix {inherit pkgs;};
}
