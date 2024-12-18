# nix eval -f . --json config.kubernetes.generated --show-trace
{
  system ? builtins.currentSystem,
  kubenix ?
    import (fetchTarball {
      url = "https://github.com/hall/kubenix/archive/master.tar.gz";
    }),
  ...
}: (kubenix.evalModules.${system} {
  module = {kubenix, ...}: {
    imports = [
      kubenix.modules.helm
    ];
    kubernetes = {
      helm = {
        releases = {
          kubernetes-dashboard = {
            chart = kubenix.lib.helm.fetch {
              repo = "https://kubernetes.github.io/dashboard/";
              chart = "kubernetes-dashboard";
              sha256 = "sha256-OeSmRd4xiq6R5cx7so8qGLfVeQvkCiZqtdTgeOEGNew=";
            };
          };
        };
      };
    };
  };
})
