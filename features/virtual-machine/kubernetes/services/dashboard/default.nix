# nix eval -f . --json config.kubernetes.generated --show-trace
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
  serviceName = "dashboard";
  servicePort = 80;
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
              repo = "https://kubernetes.github.io/dashboard/";
              chart = "kubernetes-dashboard";
              sha256 = "sha256-qs4aqsTJvcPgGx70Pzvjc5SMEg6ZwhsE4dEKQ8Yp9lc=";
            };
          };
        };
      };
      resources = {
        ingresses = pkgs.lib.mkForce {
          "${serviceName}" = {
            metadata = {
              annotations = {
                "kubernetes.io/ingress.class" = pkgs.lib.mkForce "traefik";
              };
            };
            spec = {
              ingressClassName = "traefik";
              rules = [
                {
                  host = "${serviceName}.${settings.hostname}";
                  http = {
                    paths = [
                      {
                        path = "/";
                        pathType = "Prefix";
                        backend = {
                          service = {
                            name = "${serviceName}";
                            port = {
                              number = servicePort;
                            };
                          };
                        };
                      }
                    ];
                  };
                }
              ];
            };
          };
        };
      };
    };
  };
})
