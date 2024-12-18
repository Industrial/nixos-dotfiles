{
  pkgs ? import <nixpkgs> {},
  settings ? {hostname = "localhost";},
  system ? builtins.currentSystem,
  kubenix ?
    import (fetchTarball {
      url = "https://github.com/hall/kubenix/archive/master.tar.gz";
    }),
  ...
}: let
  serviceName = "openstreetmap";
in (kubenix.evalModules.${system} {
  module = {kubenix, ...}: {
    imports = [
      kubenix.modules.helm
    ];
    kubernetes = {
      helm = {
        releases = {
          "${serviceName}" = {
            chart = kubenix.lib.helm.fetch {
              repo = "https://developmentseed.org/osm-seed-chart/";
              chart = "osm-seed";
              sha256 = "sha256-mlYuJsnt059Hieq0P0Ksow+dT/UE+mvRboAlieUwKcM=";
            };
          };
        };
      };
      # resources = {
      #   ingresses = pkgs.lib.mkForce {
      #     "${serviceName}" = {
      #       metadata = {
      #         annotations = {
      #           "kubernetes.io/ingress.class" = pkgs.lib.mkForce "traefik";
      #         };
      #       };
      #       spec = {
      #         ingressClassName = "traefik";
      #         rules = [
      #           {
      #             host = "${serviceName}.${settings.hostname}";
      #             http = {
      #               paths = [
      #                 {
      #                   path = "/";
      #                   pathType = "Prefix";
      #                   backend = {
      #                     service = {
      #                       name = "${serviceName}";
      #                       port = {
      #                         number = 8096;
      #                       };
      #                     };
      #                   };
      #                 }
      #               ];
      #             };
      #           }
      #         ];
      #       };
      #     };
      #   };
      # };
    };
  };
})
