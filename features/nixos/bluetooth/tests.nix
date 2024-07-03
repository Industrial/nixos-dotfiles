args @ {...}: let
  feature = import ./default.nix args;
in {
  test_hardware_bluetooth_enable = {
    expr = feature.hardware.bluetooth.enable;
    expected = true;
  };
  test_hardware_bluetooth_settings_General_Enable = {
    expr = feature.hardware.bluetooth.settings.General.Enable;
    expected = "Source,Sink,Media,Socket";
  };
  test_services_blueman_enable = {
    expr = feature.services.blueman.enable;
    expected = true;
  };
}
