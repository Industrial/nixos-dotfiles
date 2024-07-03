{pkgs, ...}: let
  pr = pkgs.writeScriptBin "pr" (builtins.readFile ./bin/pr.sh);
in {
  environment.systemPackages = with pkgs; [
    gh
    pr
  ];
}
