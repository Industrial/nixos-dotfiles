# gh is a GitHub CLI tool.
{
  settings,
  pkgs,
  ...
}: let
  pr = pkgs.writeScriptBin "pr" (builtins.readFile ./bin/pr.sh);
in {
  home.packages = with pkgs; [
    gh
    pr
  ];
}
