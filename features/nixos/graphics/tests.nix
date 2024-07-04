args @ {...}: let
  feature = import ./default.nix args;
in {
  test_hardware_enableRedistributableFirmware = {
    expr = feature.hardware.enableRedistributableFirmware;
    expected = true;
  };
  test_hardware_graphics_enable = {
    expr = feature.hardware.graphics.enable;
    expected = true;
  };
  test_hardware_graphics_enable32Bit = {
    expr = feature.hardware.graphics.enable32Bit;
    expected = true;
  };
}
