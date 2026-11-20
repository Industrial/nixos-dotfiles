# Assay: Terraform toolchain, providers, cloud CLIs and the env it sets.
#
# Claims read the evaluated config (environment.variables, groups, systemPackages).
#
# KNOWN BREAKAGE, pinned so that fixing it is a visible change here: the module names its
# providers `terraform-providers.aws`, `.azurerm`, ... and the pinned nixpkgs has renamed them
# to `<namespace>_<name>` (hashicorp_aws, integrations_github, kreuzwerker_docker, ...). So
# environment.systemPackages does not evaluate at all, and any host importing this feature
# fails to build -- none does today (profiles/development.nix has it commented out). Once the
# names are fixed, `packagesAreBroken` fails; replace it with claims on the installed set.
#
# Pinned as-is and worth knowing: TF_LOG=INFO with TF_LOG_PATH=/tmp/terraform.log logs every
# run, fleet-wide, to a fixed path in the shared /tmp -- and Terraform logs can carry provider
# credentials and state values.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./default.nix];};
in
  assay.suite "terraform" {
    packagesAreBroken =
      assay.throws
      "(import ${toString ../../../common/assay/nixos.nix}).hasPackage ((import ${toString ../../../common/assay/nixos.nix}).eval {modules = [${toString ./default.nix}];}) \"terraform\""
      "attribute 'aws' missing";

    setsTerraformVariables =
      assay.subset cfg.environment.variables
      {
        TF_VAR_region = "us-west-2";
        TF_VAR_environment = "development";
        TF_LOG = "INFO";
        TF_LOG_PATH = "/tmp/terraform.log";
      };
    createsDockerGroup = assay.eq (cfg.users.groups ? docker) true;
    # The group only; the daemon is someone else's feature.
    doesNotEnableDocker = assay.eq cfg.virtualisation.docker.enable false;
  }
