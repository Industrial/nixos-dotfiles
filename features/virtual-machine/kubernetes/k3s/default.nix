{...}: {
  # I turned this off because I don't want to expose it. I'm using tailscale so
  # I don't need to expose it.
  # networking = {
  #   firewall = {
  #     allowedTCPPorts = [
  #       6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
  #       # 2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
  #       # 2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
  #     ];
  #     allowedUDPPorts = [
  #       # 8472 # k3s, flannel: required if using multi-node for inter-node networking
  #     ];
  #   };
  # };

  services = {
    k3s = {
      enable = true;
      role = "server";
      extraFlags = [
        # "--debug"
        # "--no-deploy traefik"
        # "--cluster-cidr 10.24.0.0/16"
      ];
    };
  };
}
