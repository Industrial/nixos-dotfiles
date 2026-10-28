# Colocated suite: the VM test harness validates specs and builds well-formed tests.
#
# The harness is what stands between "a spec exists" and "a control is proven", so its own
# validation has to be exercised — a harness that accepted a script with no assertion would
# manufacture passing tests that check nothing.
let
  assay = import ./../../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;
  harness = import ./harness.nix {
    lib = nixpkgsLib;
    # specProblems never touches pkgs; the stub keeps this suite from evaluating nixpkgs.
    pkgs = {};
  };

  good = {
    id = "V-268141";
    description = "IPv4 TCP syncookies";
    modules = [];
    script = "machine.succeed(\"sysctl -n net.ipv4.tcp_syncookies\")";
  };
in
  assay.suite "stig-vm-harness" {
    wellFormedSpecHasNoProblems = assay.eq (harness.specProblems good) [];

    # Each of these is a way a spec could look fine and verify nothing.
    rejectsMissingId = assay.eq (harness.specProblems (removeAttrs good ["id"]) != []) true;
    rejectsMalformedId = assay.eq (harness.specProblems (good // {id = "268141";}) != []) true;
    rejectsEmptyDescription = assay.eq (harness.specProblems (good // {description = "";}) != []) true;
    rejectsMissingModules = assay.eq (harness.specProblems (removeAttrs good ["modules"]) != []) true;
    rejectsTrivialScript = assay.eq (harness.specProblems (good // {script = "pass";}) != []) true;

    # The important one: a script that never calls machine.* cannot fail, so it is not a test.
    rejectsScriptWithNoAssertion =
      assay.eq (harness.specProblems (good // {script = "# TODO: verify this control later";}) != []) true;

    # Problems name the offending control, or a failing gate is a scavenger hunt.
    problemNamesTheControl =
      assay.eq (builtins.match ".*V-268141.*" (builtins.head (harness.specProblems (good // {script = "pass";}))) != null) true;
  }
