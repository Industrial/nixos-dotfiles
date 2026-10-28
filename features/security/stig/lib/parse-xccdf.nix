# Pure projection of the vendored Anduril NixOS STIG XCCDF.
#
# Nix has no XML parser, and the NixOS module eval path must stay free of import-from-derivation,
# so `bin/stig-xccdf-to-json` projects the XCCDF to JSON at author time and the result is
# committed next to it. The XML remains the audit source of truth; this file refuses to evaluate
# unless the projection still hashes back to that exact XML, so a stale or hand-edited JSON is an
# eval failure rather than silent drift.
#
# Depends on builtins only — no lib, no pkgs — so suites can import it with no fixture.
let
  xmlPath = ../data/Anduril_NixOS_STIG-V1R3.xccdf.xml;
  jsonPath = ../data/Anduril_NixOS_STIG-V1R3.controls.json;

  doc = builtins.fromJSON (builtins.readFile jsonPath);
  benchmark = doc.benchmark;
  controls = doc.controls;
  ids = builtins.attrNames controls;

  xmlHash = builtins.hashFile "sha256" xmlPath;

  idsWith = pred: builtins.filter (id: pred controls.${id}) ids;
  countWhere = pred: builtins.length (idsWith pred);

  severities = ["high" "medium" "low"];
  observedCounts = builtins.listToAttrs (map (sev: {
      name = sev;
      value = countWhere (c: c.severity == sev);
    })
    severities);

  # Properties recorded in data/PROVENANCE.md. They are asserted here rather than merely
  # documented so that replacing the benchmark cannot quietly change what we believe about it.
  invariants = [
    {
      ok = xmlHash == benchmark.sourceSha256;
      msg = "vendored XCCDF hashes to ${xmlHash} but the projection records ${benchmark.sourceSha256} — re-run bin/stig-xccdf-to-json";
    }
    {
      ok = builtins.length ids == benchmark.controlCount;
      msg = "projection declares ${toString benchmark.controlCount} controls but carries ${toString (builtins.length ids)}";
    }
    {
      ok = benchmark.controlCount == 103;
      msg = "expected 103 controls (Anduril NixOS STIG V1R3), found ${toString benchmark.controlCount} — a new release needs manifest.nix, controls/ and tests/vm/ updated first";
    }
    {
      ok = observedCounts == benchmark.severityCounts;
      msg = "severity counts disagree with the projection header";
    }
    {
      ok = observedCounts.high == 11 && observedCounts.medium == 91 && observedCounts.low == 1;
      msg = "expected 11 CAT I / 91 CAT II / 1 CAT III, found ${toString observedCounts.high} / ${toString observedCounts.medium} / ${toString observedCounts.low}";
    }
    {
      # Every check in this STIG is manual; there is no OVAL content and no scanner can grade a
      # host against it. If this ever flips, tests/vm/ and lib/report.nix stop being the only
      # verification path and the design should be revisited.
      ok = benchmark.allChecksManual && countWhere (c: !c.checkManual) == 0;
      msg = "projection reports non-manual checks — this STIG is expected to be manual-only";
    }
    {
      ok = countWhere (c: c.fixtext == "" || c.checkContent == "") == 0;
      msg = "some controls carry empty fixtext or check content";
    }
    {
      ok = countWhere (c: c.cci == []) == 0;
      msg = "some controls carry no CCI mapping — the report's 800-53 column depends on it";
    }
  ];

  failures = builtins.filter (i: !i.ok) invariants;
in
  if failures != []
  then
    builtins.throw ''
      features/security/stig: vendored STIG benchmark failed validation.
      ${builtins.concatStringsSep "\n" (map (f: "  - ${f.msg}") failures)}
    ''
  else {
    inherit benchmark controls ids;

    # Convenience accessors used by manifest.nix, controls/ and lib/report.nix.
    severityCounts = observedCounts;
    idsBySeverity = builtins.listToAttrs (map (sev: {
        name = sev;
        value = idsWith (c: c.severity == sev);
      })
      severities);

    # CAT I. These are the rows that must never read "Open" on a hardened target.
    catOne = idsWith (c: c.severity == "high");

    get = id:
      if builtins.hasAttr id controls
      then controls.${id}
      else builtins.throw "features/security/stig: no such control ${id} in ${benchmark.title} V1R${benchmark.release}";
  }
