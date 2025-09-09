{
  config,
  lib,
  pkgs,
  ...
}: {
  # Terraform for Infrastructure as Code
  environment = {
    systemPackages = with pkgs; [
      # Terraform
      terraform
      terraform-ls
      terraform-docs

      # Terraform providers
      terraform-providers.aws
      terraform-providers.azurerm
      terraform-providers.google
      terraform-providers.kubernetes
      terraform-providers.docker
      terraform-providers.github
      terraform-providers.gitlab
      terraform-providers.vault
      terraform-providers.consul
      terraform-providers.nomad

      # Terraform utilities
      tflint
      tfsec
      # checkov  # Temporarily disabled due to cyclonedx-python-lib dependency issue
      terrascan
      infracost

      # Cloud CLIs
      awscli2
      azure-cli
      google-cloud-sdk

      # Infrastructure tools
      packer
      consul
      vault
      nomad

      # Kubernetes tools
      kubectl
      helm
      kustomize
      k9s
      kubectx
      # kubectl-context

      # # Container tools
      # docker
      # docker-compose
      # podman
      # buildah
      # skopeo

      # # Git tools
      # git
      # git-lfs
      # gh
      # glab

      # # YAML/JSON tools
      # yq
      # jq
      # yaml-language-server

      # # Text editors
      # vim
      # nano

      # # Build tools
      # make
      # gnumake
      # pkg-config
    ];
  };

  # Terraform environment variables
  environment = {
    variables = {
      TF_VAR_region = "us-west-2";
      TF_VAR_environment = "development";
      TF_LOG = "INFO";
      TF_LOG_PATH = "/tmp/terraform.log";
    };
  };

  # Docker group for container access
  users = {
    groups = {
      docker = {};
    };
  };
}
