let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  inputs = import ../../../../host/test/inputs.nix;
  feature = import ./default.nix {inherit pkgs settings inputs;};
in [
  {
    name = "cryptpad_test";
    actual = feature.services.cryptpad.enable;
    expected = true;
  }
  {
    name = "cryptpad_test";
    actual = feature.services.cryptpad.configureNginx;
    expected = false;
  }
  {
    name = "cryptpad_test";
    actual = feature.services.cryptpad.settings.httpUnsafeOrigin;
    expected = "http://127.0.0.1:4020";
  }
  {
    name = "cryptpad_test";
    actual = feature.services.cryptpad.settings.httpSafeOrigin;
    expected = "http://127.0.0.1:4020";
  }
  {
    name = "cryptpad_test";
    actual = feature.services.cryptpad.settings.httpAddress;
    expected = "127.0.0.1";
  }
  {
    name = "cryptpad_test";
    actual = feature.services.cryptpad.settings.httpPort;
    expected = 4020;
  }
  {
    name = "cryptpad_test";
    actual = feature.services.cryptpad.settings.adminKeys;
    expected = ["[tom@127.0.0.1:4020/f5bdoXYd9Jlw0pao6HRYE7jMcLl0Ky3+tvI-OG4kBZI=]"];
  }
]
