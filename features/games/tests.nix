args @ {...}: {
  flatpak = import ./flatpak/tests.nix args;
  lutris = import ./lutris/tests.nix args;
  path-of-building = import ./path-of-building/tests.nix args;
  steam = import ./steam/tests.nix args;
}
