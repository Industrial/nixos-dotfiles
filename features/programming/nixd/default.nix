# NixD is a Nix Language Server.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nixd
  ];
}
