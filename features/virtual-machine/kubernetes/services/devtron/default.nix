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
          devtron = {
            chart = kubenix.lib.helm.fetch {
              repo = "https://helm.devtron.ai";
              chart = "devtron-operator";
              sha256 = "sha256-BZ93s2cWQg4ghdFp6sMHpN46tEjeZRxOfrpAqyy93Fs=";
            };
            # values = {
            #   immich = {
            #     persistence = {
            #       library = {
            #         existingClaim = "library-pvc";
            #       };
            #     };
            #   };
            # };
          };
        };
      };
    };
  };
})
