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
  serviceName = "baserow";
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
              repo = "https://baserow.gitlab.io/baserow-chart";
              chart = "${serviceName}";
              sha256 = "sha256-33Zzi6GzO1ZnQY5PjtKcfza1JBYfcHA9X7VVpleJ3+A=";
            };
            values = {
              caddy.enabled = false; # Disable caddy since we're using traefik
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
                            name = "${serviceName}-${serviceName}-frontend";
                            port = {
                              number = 80;
                            };
                          };
                        };
                      }
                      {
                        path = "/api";
                        pathType = "Prefix";
                        backend = {
                          service = {
                            name = "${serviceName}-${serviceName}-backend-wsgi";
                            port = {
                              number = 80;
                            };
                          };
                        };
                      }
                      {
                        path = "/ws";
                        pathType = "Prefix";
                        backend = {
                          service = {
                            name = "${serviceName}-${serviceName}-backend-asgi";
                            port = {
                              number = 80;
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
