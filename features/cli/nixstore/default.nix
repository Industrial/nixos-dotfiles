# nixstore — store path-info CLI (from github:Industrial/assay).
{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = [
    inputs.assay.packages.${pkgs.stdenv.hostPlatform.system}.nixstore
  ];
}
