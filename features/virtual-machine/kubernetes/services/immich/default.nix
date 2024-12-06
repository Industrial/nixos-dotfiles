# nix eval -f . --json config.kubernetes.generated --show-trace
{
  system ? builtins.currentSystem,
  kubenix ?
    import (fetchTarball {
      url = "https://github.com/hall/kubenix/archive/master.tar.gz";
    }),
}: (kubenix.evalModules.${system} {
  module = {kubenix, ...}: {
    imports = [
      kubenix.modules.helm
    ];
    kubernetes = {
      helm = {
        releases = {
          immich = {
            chart = kubenix.lib.helm.fetch {
              repo = "https://immich-app.github.io/immich-charts";
              chart = "immich";
              sha256 = "sha256-oRJpFU/dgwgg+2s6PPUgVK69HBIYs3DptNn69eYul8M=";
            };
            values = {
              immich = {
                persistence = {
                  library = {
                    existingClaim = "library-pvc";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
})
