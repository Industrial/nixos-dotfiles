args @ {...}: let
  feature = import ./default.nix args;
in {
  test_services_cryptpad_enable = {
    expr = feature.services.cryptpad.enable;
    expected = true;
  };
  test_services_cryptpad_configureNginx = {
    expr = feature.services.cryptpad.configureNginx;
    expected = false;
  };
  test_services_cryptpad_settings_httpUnsafeOrigin = {
    expr = feature.services.cryptpad.settings.httpUnsafeOrigin;
    expected = "http://127.0.0.1:4020";
  };
  test_services_cryptpad_settings_httpSafeOrigin = {
    expr = feature.services.cryptpad.settings.httpSafeOrigin;
    expected = "http://127.0.0.1:4020";
  };
  test_services_cryptpad_settings_httpAddress = {
    expr = feature.services.cryptpad.settings.httpAddress;
    expected = "127.0.0.1";
  };
  test_services_cryptpad_settings_httpPort = {
    expr = feature.services.cryptpad.settings.httpPort;
    expected = 4020;
  };
  test_services_cryptpad_settings_adminKeys = {
    expr = feature.services.cryptpad.settings.adminKeys;
    expected = ["[tom@127.0.0.1:4020/f5bdoXYd9Jlw0pao6HRYE7jMcLl0Ky3+tvI-OG4kBZI=]"];
  };
}
