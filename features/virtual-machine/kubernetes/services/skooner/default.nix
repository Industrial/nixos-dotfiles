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
  serviceName = "skooner";
  servicePort = 80;
  containerPort = 4654;
  metadata = {
    name = serviceName;
    labels = {
      app = serviceName;
    };
  };
in (kubenix.evalModules.${system} {
  module = {kubenix, ...}: {
    imports = [
      kubenix.modules.helm
    ];
    kubernetes = {
      resources = {
        services = {
          "${serviceName}" = {
            inherit metadata;
            spec = {
              ports = [
                {
                  port = servicePort;
                  name = "web";
                  targetPort = containerPort;
                }
              ];
              selector = {
                app = serviceName;
              };
              type = "ClusterIP";
            };
          };
        };
        deployments = {
          "${serviceName}" = {
            inherit metadata;
            spec = {
              replicas = 1;
              selector = {
                matchLabels = {
                  app = serviceName;
                };
              };
              template = {
                metadata = {
                  labels = {
                    app = serviceName;
                  };
                };
                spec = {
                  containers = {
                    prowlarr = {
                      image = "ghcr.io/skooner-k8s/skooner:stable";
                      ports = [
                        {
                          containerPort = containerPort;
                          name = "web";
                        }
                      ];
                      resources = {
                        requests = {
                          cpu = "100m";
                          memory = "128Mi";
                        };
                        limits = {
                          cpu = "1000m";
                          memory = "1Gi";
                        };
                      };
                      env = [
                        {
                          name = "TZ";
                          value = "Etc/UTC";
                        }
                        {
                          name = "PUID";
                          value = "1000";
                        }
                        {
                          name = "PGID";
                          value = "1000";
                        }
                      ];
                    };
                  };
                };
              };
            };
          };
        };
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
