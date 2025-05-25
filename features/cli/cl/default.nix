{
  pkgs,
  inputs, # Expect 'inputs' from specialArgs
  ...
}: let
  # inputs.cl-src is a store path to the tool's source directory
  # callPackage will look for default.nix within this store path
  clPkg = pkgs.callPackage inputs.cl-src {};
in {
  # The cl feature previously didn't have an enable option, it just added to systemPackages.
  # We'll keep that behavior.
  environment.systemPackages = [clPkg];
}
