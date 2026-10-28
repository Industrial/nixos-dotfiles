# Colocated suite: the acknowledged control set is complete and agrees with the benchmark.
#
# The manifest's real job is to THROW when upstream and the acknowledged list diverge. That
# behaviour is exercised by falsification (temporarily add or drop an id and eval), recorded as
# evidence on the leaf rather than asserted here: a suite cannot both import the manifest and
# observe it throwing without re-evaluating a mutated copy.
let
  assay = import ./../../../../common/assay/default.nix;
  manifest = import ./manifest.nix;
  stig = import ./parse-xccdf.nix;

  sorted = builtins.sort (a: b: a < b) manifest.ids;
in
  assay.suite "stig-manifest" {
    count = assay.eq manifest.count 103;
    countMatchesBenchmark = assay.eq manifest.count stig.benchmark.controlCount;
    release = assay.eq manifest.release "V1R3";

    # Equality with the parsed set is the guard; assert it holds in the committed state.
    matchesParsedSet = assay.eq manifest.ids stig.ids;
    noneMissing = assay.eq (builtins.filter (id: !builtins.elem id manifest.ids) stig.ids) [];
    noneExtra = assay.eq (builtins.filter (id: !builtins.elem id stig.ids) manifest.ids) [];

    # Sorted and duplicate-free, so reviewing a release delta is a readable diff.
    isSorted = assay.eq manifest.ids sorted;
    noDuplicates = assay.eq (builtins.length (builtins.attrNames (builtins.listToAttrs (map (id: {
        name = id;
        value = true;
      })
      manifest.ids))))
    103;

    everyIdResolves = assay.eq (builtins.length (builtins.filter (id: (stig.get id).ruleId == null) manifest.ids)) 0;

    # Severity is reachable for every acknowledged id — lib/report.nix groups on it.
    everyIdHasSeverity = assay.eq (builtins.length (builtins.filter (id: !builtins.elem (stig.get id).severity ["high" "medium" "low"]) manifest.ids)) 0;
  }
