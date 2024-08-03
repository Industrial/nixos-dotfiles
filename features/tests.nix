args @ {...}: {
  cli = import ./cli/tests.nix args;
  communication = import ./communication/tests.nix args;
  crypto = import ./crypto/tests.nix args;
  # darwin = import ./darwin/tests.nix args;
  games = import ./games/tests.nix args;
  hardware = import ./hardware/tests.nix args;
  media = import ./media/tests.nix args;
  monitoring = import ./monitoring/tests.nix args;
  network = import ./network/tests.nix args;
  nix = import ./nix/tests.nix args;
  nixos = import ./nixos/tests.nix args;
  office = import ./office/tests.nix args;
  programming = import ./programming/tests.nix args;
  security = import ./security/tests.nix args;
  virtual-machine = import ./virtual-machine/tests.nix args;
  window-manager = import ./window-manager/tests.nix args;
}
