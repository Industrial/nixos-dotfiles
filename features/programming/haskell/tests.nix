args @ {...}: let
  feature = import ./default.nix args;
in {
  test_nix_settings_trustedPublicKeys = {
    expr = builtins.elem "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" feature.nix.settings.trusted-public-keys;
    expected = true;
  };
  test_nix_settings_substituters = {
    expr = builtins.elem "https://cache.iog.io" feature.nix.settings.substituters;
    expected = true;
  };
}
