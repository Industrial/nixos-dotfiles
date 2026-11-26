# Colocated suite: the shared procedural exclusions are the three expected controls, each
# with a reason an assessor can read.
let
  assay = import ./../../../../common/assay/default.nix;
  exclusions = import ./procedural-exclusions.nix;
  manifest = import ./manifest.nix;
  ids = builtins.attrNames exclusions;
in
  assay.suite "stig-procedural-exclusions" {
    exactlyTheThreeProceduralControls = assay.eq ids ["V-268079" "V-268125" "V-268180"];
    everyIdIsInTheManifest = assay.eq (builtins.filter (id: !builtins.elem id manifest.ids) ids) [];
    everyReasonIsWritten =
      assay.eq (builtins.filter (id: builtins.stringLength exclusions.${id} <= 40) ids) [];
    # Only true while no such account exists, so the text has to say it must be revisited.
    emergencyAccountReasonIsConditional =
      assay.eq (builtins.match ".*re-asserted.*" exclusions."V-268079" != null) true;
  }
