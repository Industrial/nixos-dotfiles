let
  pkgs = import <nixpkgs> {};
  settings = import ../../../hosts/test/settings.nix;
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
    expr = builtins.elem pkgs.vscodeWithExtensions feature.environment.systemPackages;
    expected = true;
  }
  {
    expr = builtins.elem pkgs.alejandra feature.environment.systemPackages;
    expected = true;
  }
]
