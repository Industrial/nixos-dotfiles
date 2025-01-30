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
  serviceName = "portainer";
  servicePort = 9443;
in (kubenix.evalModules.${system} {
  module = {kubenix, ...}: {
    imports = [
      kubenix.modules.helm
    ];
    kubernetes = {
      helm = {
        releases = {
          portainer = {
            chart = kubenix.lib.helm.fetch {
              repo = "https://portainer.github.io/k8s/";
              chart = "portainer";
              sha256 = "sha256-HHDEzeGnCLqqyolyRmzIW7Cyfj03znww2VYRQ6JZYx0=";
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
