args @ {...}: let
  feature = import ./default.nix args;
in {
  test_i18n_defaultLocale = {
    expr = feature.i18n.defaultLocale;
    expected = "en_US.UTF-8";
  };
  test_i18n_extraLocaleSettings = {
    expr = feature.i18n.extraLocaleSettings;
    expected = {
      LC_ADDRESS = "nl_NL.UTF-8";
      LC_IDENTIFICATION = "nl_NL.UTF-8";
      LC_MEASUREMENT = "nl_NL.UTF-8";
      LC_MONETARY = "nl_NL.UTF-8";
      LC_NAME = "nl_NL.UTF-8";
      LC_NUMERIC = "nl_NL.UTF-8";
      LC_PAPER = "nl_NL.UTF-8";
      LC_TELEPHONE = "nl_NL.UTF-8";
      LC_TIME = "nl_NL.UTF-8";
    };
  };
}
