# gh is a GitHub CLI tool.
{
  c9config,
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
