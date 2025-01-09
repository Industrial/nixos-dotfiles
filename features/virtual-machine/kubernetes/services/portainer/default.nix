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
          portainer = {
            chart = kubenix.lib.helm.fetch {
              repo = "https://portainer.github.io/k8s/";
              chart = "portainer";
              sha256 = "sha256-HHDEzeGnCLqqyolyRmzIW7Cyfj03znww2VYRQ6JZYx0=";
            };
          };
        };
      };
    };
  };
})
