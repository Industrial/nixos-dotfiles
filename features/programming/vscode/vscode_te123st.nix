let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  # inputs = {
  #   nix-vscode-extensions = {
  #     extensions = {
  #     };
  #     ${pkgs.system};
  #   };
  # };
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = builtins.elem pkgs.vscodeWithExtensions feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = builtins.elem pkgs.alejandra feature.environment.systemPackages;
    expected = true;
  }
]
