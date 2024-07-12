{pkgs, ...}: let
  feature = import ./default.nix {inherit pkgs;};
in {
  environment = {
    systemPackages = {
      test = {
        expr = builtins.elem pkgs.gleam feature.environment.systemPackages;
        expected = true;
      };
    };
  };
}
