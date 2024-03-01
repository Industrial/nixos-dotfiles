# NixD is a Nix Language Server.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    nixd
  ];
}
