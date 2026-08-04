# Colocated suite: ollama packages + service enable.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (let
      pkgs = {
        ollama = "ollama";
        ollama-cuda = "ollama-cuda";
        aider-chat = "aider-chat";
      };
    in import ${modFile} { inherit pkgs; })
  '';
in
  assay.suite "ollama" {
    systemPackages = assay.eq "${mod}.environment.systemPackages" ''[ "ollama" "ollama-cuda" "aider-chat" ]'';
    enabled = assay.eq "${mod}.services.ollama.enable" "true";
    apiBase = assay.eq "${mod}.environment.sessionVariables.OLLAMA_API_BASE" "\"http://localhost:11434\"";
  }
