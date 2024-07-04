args @ {...}: let
  feature = import ./default.nix args;
in {
  test_console_font = {
    expr = feature.console.font;
    expected = "Lat2-Terminus16";
  };
  test_console_keyMap = {
    expr = feature.console.keyMap;
    expected = "us";
  };
}
