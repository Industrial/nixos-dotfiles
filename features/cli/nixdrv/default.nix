# nixdrv — derivation helpers CLI (from github:Industrial/assay).
{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = [
    inputs.assay.packages.${pkgs.system}.nixdrv
  ];
}
