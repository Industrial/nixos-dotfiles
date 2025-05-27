{pkgs, ...}: {
  lutris = import ./lutris/lutris.test.nix {inherit pkgs;};
  path-of-building = import ./path-of-building/path-of-building.test.nix {inherit pkgs;};
  wowup = import ./wowup/wowup.test.nix {inherit pkgs;};
}
