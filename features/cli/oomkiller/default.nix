{
  pkgs,
  inputs, # Expect 'inputs' from specialArgs
  ...
}: let
  # inputs.oomkiller-src is a store path to the tool's source directory
  # callPackage will look for default.nix within this store path
  oomkillerPkg = pkgs.callPackage inputs.oomkiller-src {};
in {
  # The oomkiller feature adds the tool to systemPackages.
  environment.systemPackages = [oomkillerPkg];
}
