# nixfetch — fixed-output fetch / hash verify CLI (from github:Industrial/assay).
{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = [
    inputs.assay.packages.${pkgs.stdenv.hostPlatform.system}.nixfetch
  ];
}
