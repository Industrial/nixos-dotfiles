# NixD is a Nix Language Server.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    nixd
  ];
}
