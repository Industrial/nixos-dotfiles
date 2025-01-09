{
  inputs,
  settings,
  pkgs,
  ...
}: let
  generateManifests = import ../lib/generateManifests.nix {inherit inputs settings pkgs;};
  generateHostEntries = import ../lib/generateHostEntries.nix {inherit settings;};

  # List of services to deploy
  services = [
    # "immich"
    # "baserow"
    "jellyfin"
    "pairdrop"
    "portainer"
    "rsshub"
  ];

  # Generate manifests for services
  manifests = generateManifests services;

  # Generate host entries for services
  extraHosts = generateHostEntries services;
in {
  services = {
    k3s = {
      enable = true;
      role = "server";
      inherit manifests;
      extraFlags = "--disable traefik=false"; # Explicitly enable Traefik
    };
  };

  networking = {
    firewall = {
      allowedTCPPorts = [
        # Kubernetes API server
        6443
        # Kubelet API
        10250
        # HTTP for Traefik ingress
        80
        # HTTPS for Traefik ingress
        443
      ];
      allowedUDPPorts = [
        # Flannel VXLAN
        8472
      ];
    };

    inherit extraHosts;
  };

  # environment = {
  #   systemPackages = with pkgs; [
  #     kubernetes-helm
  #   ];
  # };
}
