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
  serviceName = "jellyfin";
  servicePort = 8096;
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
              repo = "https://jellyfin.github.io/jellyfin-helm";
              chart = "${serviceName}";
              sha256 = "sha256-uqdSUZ034DXIGsEyJEh7XXmy+Ru6ovrhw8SOf4ZqKBQ=";
            };
            values = {
              persistence = {
                config = {
                  enabled = true;
                  existingClaim = null;
                };
                media = {
                  enabled = true;
                  existingClaim = null;
                };
              };
              volumes = [
                {
                  name = "config-volume";
                  hostPath = {
                    path = "/data/jellyfin/config";
                    type = "Directory";
                  };
                }
                {
                  name = "media-volume";
                  hostPath = {
                    path = "/data/jellyfin/media";
                    type = "Directory";
                  };
                }
              ];
              volumeMounts = [
                {
                  name = "config-volume";
                  mountPath = "/config";
                }
                {
                  name = "media-volume";
                  mountPath = "/media";
                }
              ];
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
