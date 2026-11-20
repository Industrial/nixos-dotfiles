# Colocated suite for profiles/ai.nix — what the profile switches on, evaluated
# through the real option layer (lib/features.nix evalSelection), not its source text.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  features = import ../lib/features.nix {inherit (nixos) lib;};
  on = features.enabledFeatures (features.evalSelection {modules = [{profiles.ai.enable = true;}];});
  has = f: builtins.elem f on;
  catalogued = f: builtins.elem f (map (p: builtins.concatStringsSep "." (features.namePath p)) features.catalog);
in
  assay.suite "ai" {
    # claude-code owns ~/.claude; every agent surface in this profile sits on top of it.
    enablesClaudeCode = assay.eq (has "ai.claude-code") true;

    # Paseo is the chosen browser surface over the coding agents.
    enablesPaseo = assay.eq (has "ai.paseo") true;

    # cloudcli is the superseded surface and mutually exclusive with paseo (both run a
    # daemon over the same ~/.claude session files), so it must not even be switchable.
    cloudcliNotCatalogued = assay.eq (catalogued "ai.cloudcli") false;

    # openhands stays off: muninn enables this profile too, and paseo replaced it.
    openhandsNotCatalogued = assay.eq (catalogued "ai.openhands") false;

    # Exactly these two — a new entry here lands on drakkar AND muninn.
    exactSet = assay.eq on ["ai.claude-code" "ai.paseo"];
  }
