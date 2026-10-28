# Colocated suite: the compliance report scores every control, and scores it honestly.
#
# The report is the artifact an assessor reads, so the failure mode that matters is not a
# crash — it is a report that quietly says "compliant" about something nobody verified. These
# cases exercise the status derivation against synthetic configs, one per status, including the
# two that must NOT count as compliant.
let
  assay = import ./../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;
  manifest = import ./manifest.nix;

  # The report takes an evaluated config; a stub with the option shape it reads is enough to
  # exercise the scoring without building a system.
  mkReport = stigCfg: let
    pkgsStub = {
      runCommand = _name: attrs: _script: {inherit (attrs) passthru;};
      writeText = _n: _c: "written";
    };
  in
    (import ./report.nix {
      pkgs = pkgsStub;
      lib = nixpkgsLib;
      config = {
        networking.hostName = "testhost";
        security.stig =
          {
            profile = "base-safe";
            implemented = [];
            exclude = {};
            requiresReboot = {};
            satisfiedExternally = {};
            deferredVerification = {};
          }
          // stigCfg;
      };
    })
    .passthru;

  rowFor = report: id: builtins.head (builtins.filter (r: r.id == id) report.rows);

  nothingImplemented = mkReport {};
  oneImplemented = mkReport {implemented = ["V-268078"];};
  oneDeferred = mkReport {
    implemented = ["V-268117"];
    deferredVerification = {"V-268117" = "runtime state only.";};
  };
  oneRebootPending = mkReport {
    implemented = ["V-268092"];
    requiresReboot = {"V-268092" = "kernel command line.";};
  };
  oneExcluded = mkReport {exclude = {"V-268079" = "no such accounts exist.";};};
  oneExternal = mkReport {satisfiedExternally = {"V-268144" = "LUKS per hosts/<name>/disko.nix, asserted by disko.assay.nix.";};};
in
  assay.suite "stig-report" {
    # Every control in the benchmark appears, not only the implemented ones. A report that
    # silently omitted unimplemented controls would read as complete.
    scoresEveryControl = assay.eq (builtins.length nothingImplemented.rows) 103;
    rowCountMatchesManifest = assay.eq (builtins.length nothingImplemented.rows) manifest.count;

    # --- the statuses that must NOT be compliant ---
    unimplementedIsNotCompliant = assay.eq (rowFor nothingImplemented "V-268078").compliant false;
    unimplementedSaysSo = assay.eq (rowFor nothingImplemented "V-268078").status "Not Implemented";

    # Pending reboot is the distinction muninn forced: correct in the generation, not in
    # effect on the running kernel. Calling it compliant would be wrong on a live host.
    rebootPendingIsNotCompliant = assay.eq (rowFor oneRebootPending "V-268092").compliant false;
    rebootPendingSaysSo = assay.eq (rowFor oneRebootPending "V-268092").status "Configured (pending reboot)";
    rebootPendingCarriesTheReason = assay.eq (rowFor oneRebootPending "V-268092").detail "kernel command line.";

    # An exclusion is not compliance either — it is a documented non-application.
    excludedIsNotCompliant = assay.eq (rowFor oneExcluded "V-268079").compliant false;
    excludedSaysSo = assay.eq (rowFor oneExcluded "V-268079").status "Not Applicable";
    excludedCarriesTheJustification = assay.eq (rowFor oneExcluded "V-268079").detail "no such accounts exist.";

    # --- the statuses that are compliant, and why ---
    implementedIsCompliant = assay.eq (rowFor oneImplemented "V-268078").compliant true;
    implementedSaysHow = assay.eq (rowFor oneImplemented "V-268078").status "Compliant (configuration)";

    # Met outside the module set — CAT I V-268144 is decided by the disk layout, so it must
    # count as compliant AND cite evidence, not be reported as Not Implemented.
    externallySatisfiedIsCompliant = assay.eq (rowFor oneExternal "V-268144").compliant true;
    externallySatisfiedSaysHow = assay.eq (rowFor oneExternal "V-268144").status "Compliant (external evidence)";
    externallySatisfiedCitesEvidence = assay.eq (builtins.match ".*disko.*" (rowFor oneExternal "V-268144").detail != null) true;
    # ...and it clears the CAT I open list, which is the whole point.
    externallySatisfiedClearsCatOne = assay.eq (builtins.elem "V-268144" oneExternal.summary.catOneOpen) false;

    deferredIsCompliantViaVmTest = assay.eq (rowFor oneDeferred "V-268117").compliant true;
    deferredSaysHow = assay.eq (rowFor oneDeferred "V-268117").status "Compliant (VM test)";
    # ...and names the test, so the claim is checkable rather than asserted.
    deferredNamesTheTest = assay.eq (builtins.match ".*stig-V-268117.*" (rowFor oneDeferred "V-268117").detail != null) true;

    # Exclusion wins over implementation: a control both carried and excluded is Not
    # Applicable, not compliant. Otherwise an exclusion could be silently ignored.
    exclusionBeatsImplementation = let
      both = mkReport {
        implemented = ["V-268079"];
        exclude = {"V-268079" = "excluded anyway.";};
      };
    in
      assay.eq (rowFor both "V-268079").status "Not Applicable";

    # --- severity and CCI come from the benchmark, not from us ---
    severityIsFromTheBenchmark = assay.eq (rowFor nothingImplemented "V-268131").category "CAT I";
    cciIsFromTheBenchmark = assay.eq (rowFor nothingImplemented "V-268078").cci [
      "CCI-000366"
      "CCI-000382"
      "CCI-002314"
      "CCI-002322"
    ];

    # --- the summary must not flatter the host ---
    summaryCountsOnlyRealCompliance = assay.eq nothingImplemented.summary.compliant 0;
    summaryCountsTheOneCompliant = assay.eq oneImplemented.summary.compliant 1;
    rebootPendingIsNotCountedCompliant = assay.eq oneRebootPending.summary.compliant 0;

    # CAT I controls that are not compliant are called out by id, because those are the rows
    # that decide whether a host can be fielded at all.
    catOneOpenIsListed = assay.eq (builtins.elem "V-268131" nothingImplemented.summary.catOneOpen) true;
    catOneOpenCountMatchesBenchmark = assay.eq (builtins.length nothingImplemented.summary.catOneOpen) 11;
  }
