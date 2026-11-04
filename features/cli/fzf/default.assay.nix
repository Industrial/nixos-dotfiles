# Colocated suite: systemPackages and fzf session variables from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {fzf = "fzf";};
  mod = import ./default.nix {inherit pkgs;};
  env = mod.environment.sessionVariables;
  has = pattern: builtins.match ".*${pattern}.*" env.FZF_DEFAULT_OPTS != null;
in
  assay.suite "fzf" {
    systemPackages = assay.eq mod.environment.systemPackages ["fzf"];
    defaultCommand = assay.eq env.FZF_DEFAULT_COMMAND "fd --type f --hidden --exclude .git";
    layout = assay.eq (has "--layout=reverse") true;
    previewFiles = assay.eq (has "bat --style=numbers") true;
    previewDirectories = assay.eq (has "eza --tree") true;
    # Neutral until wave 7: no hand-picked hex palette in the fzf options.
    noHardcodedPalette = assay.eq (has "#[0-9a-fA-F]{3,6}") false;
  }
