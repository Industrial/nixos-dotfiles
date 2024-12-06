{
  inputs,
  settings,
  ...
}: (inputs.kubenix.evalModules.${settings.system} {
  module = {kubenix, ...}: {
    imports = [
      kubenix.modules.helm
    ];
    kubernetes = {
      helm = {
        releases = {
          immich = {
            chart = kubenix.lib.helm.fetch {
              repo = "https://helm.devtron.ai";
              chart = "devtron-operator";
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
