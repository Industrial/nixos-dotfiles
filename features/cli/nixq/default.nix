# nixq — NixOS query / structural equality CLI (from github:Industrial/assay).
{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = [
    inputs.assay.packages.${pkgs.stdenv.hostPlatform.system}.nixq
  ];
}
