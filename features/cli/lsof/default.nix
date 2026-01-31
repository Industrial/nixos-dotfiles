{
  pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    lsof
  ];
}