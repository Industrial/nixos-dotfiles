args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_networking_extraHosts = {
    expr = feature.networking.extraHosts;
    expected = "10.1.1.2 api.kube";
  };
  test_environment_systemPackages_kompose = {
    expr = builtins.elem pkgs.kompose feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_kubectl = {
    expr = builtins.elem pkgs.kubectl feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_kubernetes = {
    expr = builtins.elem pkgs.kubernetes feature.environment.systemPackages;
    expected = true;
  };
  test_services_kubernetes_roles = {
    expr = feature.services.kubernetes.roles;
    expected = ["master" "node"];
  };
  test_services_kubernetes_masterAddress = {
    expr = feature.services.kubernetes.masterAddress;
    expected = "api.kube";
  };
  test_services_kubernetes_apiserverAddress = {
    expr = feature.services.kubernetes.apiserverAddress;
    expected = "https://api.kube:6443";
  };
  test_services_kubernetes_easyCerts = {
    expr = feature.services.kubernetes.easyCerts;
    expected = true;
  };
  test_services_kubernetes_apiserver = {
    expr = feature.services.kubernetes.apiserver;
    expected = {
      securePort = 6443;
      advertiseAddress = "10.1.1.2";
    };
  };
  test_services_kubernetes_addons_dns_enable = {
    expr = feature.services.kubernetes.addons.dns.enable;
    expected = true;
  };
  test_services_kubernetes_kubelet_extraOpts = {
    expr = feature.services.kubernetes.kubelet.extraOpts;
    expected = "--fail-swap-on=false";
  };
}
