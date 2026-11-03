# Colocated suite: the external-evidence roster names real controls and cites real files.
#
# This roster is the one place a control can be called compliant without a control module
# backing it, so the bar is that every claim is checkable. An id the benchmark does not
# contain would be a claim about nothing; a citation that names no file would be an assertion
# rather than evidence.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./external-evidence.nix {};
  manifest = import ./../lib/manifest.nix;

  external = mod.security.stig.satisfiedExternally;
  ids = builtins.attrNames external;
in
  assay.suite "stig-external-evidence" {
    # The roster is not empty — an empty one would silently withdraw a CAT I claim.
    isNotEmpty = assay.eq (builtins.length ids > 0) true;

    # Every id is one the benchmark actually contains. A typo would otherwise claim a control
    # that does not exist, and inflate profiles/full.assay.nix's completeness count.
    everyIdIsInTheManifest =
      assay.eq (builtins.filter (id: !builtins.elem id manifest.ids) ids) [];

    # The roster is exactly V-268144 today. Asserted rather than counted so that adding a
    # second externally-satisfied control is a deliberate edit to this suite, not a silent
    # widening of the one exemption route in the baseline.
    carriesOnlyTheLuksControl = assay.eq ids ["V-268144"];

    # Each citation names checkable evidence — a file that asserts the property — rather than
    # merely claiming the control is fine.
    everyReasonCitesAFile =
      assay.eq (builtins.all (id: builtins.match ".*disko\\.assay\\.nix.*" external.${id} != null) ids) true;

    # And is written, not stubbed. The report renders this string to an assessor.
    everyReasonIsWritten =
      assay.eq (builtins.all (id: builtins.stringLength external.${id} > 60) ids) true;
  }
