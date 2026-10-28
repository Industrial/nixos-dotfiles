# Colocated suite: V-268139 — usbguard enabled, but never with an empty policy.
#
# The case that matters is the empty one. Enabling usbguard with no ruleset blocks every
# unauthorised USB device including the keyboard needed to fix it, so the control must refuse
# rather than produce a host nobody can type on.
let
  assay = import ./../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  control = rules:
    import ./V-268139.nix {
      lib = nixpkgsLib;
      config.services.usbguard = {inherit rules;};
    };

  verdict = mod: (builtins.head mod.assertions).assertion;

  noPolicy = control null;
  emptyPolicy = control "";
  withPolicy = control "allow id 1d6b:0002 serial \"0000:00:14.0\"";
in
  assay.suite "stig-V-268139" {
    refusesWithNoPolicy = assay.eq (verdict noPolicy) false;
    refusesWithAnEmptyPolicy = assay.eq (verdict emptyPolicy) false;
    acceptsAGeneratedPolicy = assay.eq (verdict withPolicy) true;

    # The message has to be actionable: the exact commands, and the escape hatch.
    messageGivesTheGeneratePolicyCommand =
      assay.eq (builtins.match ".*usbguard generate-policy.*" (builtins.head noPolicy.assertions).message != null) true;
    messageWarnsAboutTheKeyboard =
      assay.eq (builtins.match ".*keyboard.*" (builtins.head noPolicy.assertions).message != null) true;
    messageOffersExclusion =
      assay.eq (builtins.match ".*security\\.stig\\.exclude.*" (builtins.head noPolicy.assertions).message != null) true;
  }
