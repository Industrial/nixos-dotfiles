args @ {...}: {
  bluetooth = import ./bluetooth/tests.nix args;
  boot = import ./boot/tests.nix args;
  console = import ./console/tests.nix args;
  docker = import ./docker/tests.nix args;
  fonts = import ./fonts/tests.nix args;
  graphics = import ./graphics/tests.nix args;
  i18n = import ./i18n/tests.nix args;
  networking = import ./networking/tests.nix args;
  printing = import ./printing/tests.nix args;
  security = import ./security/tests.nix args;
  sound = import ./sound/tests.nix args;
  system = import ./system/tests.nix args;
  time = import ./time/tests.nix args;
  users = import ./users/tests.nix args;
  window-managers = import ./window-managers/tests.nix args;
}
