# nix eval -f . --json config.kubernetes.generated --show-trace
let
  kubenix = import (fetchTarball {
    url = "https://github.com/hall/kubenix/archive/master.tar.gz";
  });
in
  kubenix.evalModules.${builtins.currentSystem} {
    module = {kubenix, ...}: {
      imports = [kubenix.modules.helm];
      kubernetes.helm.releases.example = {
        chart = kubenix.lib.helm.fetch {
          repo = "https://kubernetes.github.io/dashboard/";
          chart = "kubernetes-dashboard";
          sha256 = "sha256-OeSmRd4xiq6R5cx7so8qGLfVeQvkCiZqtdTgeOEGNew=";
        };
      };
      # kubernetes.api.resources.core.v1.Service.example-kubernetes-dashboard-metrics-scraper.spec.ports = {
      #   protocol = "TCP";
      # };
    };
  }
