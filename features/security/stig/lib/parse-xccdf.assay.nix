# Colocated suite: the vendored STIG projection matches the properties PROVENANCE.md records.
let
  assay = import ./../../../../common/assay/default.nix;
  stig = import ./parse-xccdf.nix;
in
  assay.suite "stig-parse-xccdf" {
    controlCount = assay.eq (builtins.length stig.ids) 103;
    declaredCount = assay.eq stig.benchmark.controlCount 103;

    severitySplit = assay.eq stig.severityCounts {
      high = 11;
      medium = 91;
      low = 1;
    };
    catOneCount = assay.eq (builtins.length stig.catOne) 11;

    release = assay.eq stig.benchmark.release "3";
    version = assay.eq stig.benchmark.version "1";
    benchmarkDate = assay.eq stig.benchmark.benchmarkDate "30 Sep 2026";
    title = assay.eq stig.benchmark.title "Anduril NixOS Security Technical Implementation Guide";

    # There is no OVAL content for this STIG; every check is manual. tests/vm/ and
    # lib/report.nix exist because of this.
    allChecksManual = assay.eq stig.benchmark.allChecksManual true;

    # The projection is only trustworthy while it hashes back to the vendored XML.
    projectionPinsSource = assay.eq stig.benchmark.sourceSha256 (builtins.hashFile "sha256" ./../data/Anduril_NixOS_STIG-V1R3.xccdf.xml);
    sourceFile = assay.eq stig.benchmark.sourceFile "Anduril_NixOS_STIG-V1R3.xccdf.xml";

    idRangeLow = assay.eq (builtins.head stig.ids) "V-268078";
    idRangeHigh = assay.eq (builtins.head (builtins.filter (id: id == "V-268181") stig.ids)) "V-268181";

    # Spot-check one control end to end rather than trusting the aggregate counts alone.
    firewallControl = assay.subset (stig.get "V-268078") {
      severity = "medium";
      ruleId = "SV-268078r1130947_rule";
      ruleVersion = "ANIX-00-000010";
      title = "NixOS must enable the built-in firewall.";
      checkManual = true;
    };
    # Four CCIs on this one control — the report's 800-53 column is many-to-one, not one-to-one.
    firewallCci = assay.eq (stig.get "V-268078").cci [
      "CCI-000366"
      "CCI-000382"
      "CCI-002314"
      "CCI-002322"
    ];
    firewallFixIsDeclarative = assay.eq (builtins.match ".*networking\\.firewall\\.enable = true;.*" (stig.get "V-268078").fixtext != null) true;

    everyControlHasFix = assay.eq (builtins.length (builtins.filter (id: (stig.get id).fixtext == "") stig.ids)) 0;
    everyControlHasCheck = assay.eq (builtins.length (builtins.filter (id: (stig.get id).checkContent == "") stig.ids)) 0;
    everyControlHasCci = assay.eq (builtins.length (builtins.filter (id: (stig.get id).cci == []) stig.ids)) 0;

    # V1R3 renamed the consent banner. A V1R1 copy would still say "Department of Defense",
    # which silently fails V-268082/83/84.
    bannerIsDoW = assay.eq (builtins.length (builtins.filter (id: builtins.match ".*Department of Defense.*" (stig.get id).fixtext != null) stig.ids)) 0;

    # `get` throws on an unknown id. The throw itself is covered by falsification evidence on
    # the leaf — `assay.throws` takes a Nix source string and the runner serialises cases to
    # JSON, so a closure over this file cannot be a case. Assert the precondition instead.
    unknownControlAbsent = assay.eq (builtins.hasAttr "V-000000" stig.controls) false;
  }
