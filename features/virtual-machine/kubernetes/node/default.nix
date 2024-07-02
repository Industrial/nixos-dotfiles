{pkgs, ...}: let
  kubeMasterIP = "10.1.1.2";
  kubeMasterHostname = "api.kube";
  kubeMasterAPIServerPort = 6443;
in {
  # resolve master hostname
  networking.extraHosts = "${kubeMasterIP} ${kubeMasterHostname}";

  # packages for administration tasks
  environment.systemPackages = with pkgs; [
    kompose
    kubectl
    kubernetes
  ];

  services.kubernetes = let
    api = "https://${kubeMasterHostname}:${toString kubeMasterAPIServerPort}";
  in {
    roles = ["node"];
    masterAddress = kubeMasterHostname;
    easyCerts = true;

    # point kubelet and other services to kube-apiserver
    kubelet.kubeconfig.server = api;
    apiserverAddress = api;

    # use coredns
    addons.dns.enable = true;

    # needed if you use swap
    kubelet.extraOpts = "--fail-swap-on=false";
  };
}
