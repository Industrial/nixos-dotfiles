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
  serviceName = "pairdrop";
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
              repo = "https://charts.oecis.io";
              chart = "${serviceName}";
              sha256 = "sha256-J14JGmb4QXBaRyYCkzIvFxYhh2O+XqCwX/toXsJdS2g=";
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
                              number = 3000;
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
