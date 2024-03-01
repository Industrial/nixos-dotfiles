{
  settings,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    shell_gpt
  ];
}
