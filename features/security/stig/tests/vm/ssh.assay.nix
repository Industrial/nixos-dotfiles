# Colocated suite: the SSH VM specs.
let
  assay = import ./../../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  harness = import ./harness.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };
  specs = import ./ssh.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };

  manifest = import ./../../lib/manifest.nix;
  ids = map (s: s.id) specs;
in
  assay.suite "stig-vm-ssh" {
    allSpecsWellFormed = assay.eq (builtins.concatLists (map harness.specProblems specs)) [];
    everyIdIsInTheManifest = assay.eq (builtins.all (id: builtins.elem id manifest.ids) ids) true;
    specCount = assay.eq (builtins.length specs) 8;

    everySpecUsesTheRealProfile =
      assay.eq (builtins.all (s: builtins.any (m: builtins.match ".*base-safe\\.nix" (toString m) != null) s.modules) specs) true;

    # sshd must be up before anything is asserted, or the test races the daemon.
    everySpecWaitsForSshd =
      assay.eq (builtins.all (s: builtins.match ".*wait_for_unit\\(\"sshd\\.service\"\\).*" s.script != null) specs) true;

    # Assertions read `sshd -T`, the EFFECTIVE configuration after defaults and includes,
    # rather than the generated file. Four of these controls were published against renamed
    # or misspelled options, and a value landing on a dead attribute path still evaluates —
    # only the daemon's own resolved view catches that.
    everySpecReadsEffectiveConfig =
      assay.eq (builtins.all (s: builtins.match ".*sshd -T.*" s.script != null) specs) true;

    # The cipher spec is the one that would have caught the `setting`/`settings` typo in
    # V-268089's published fix text, so pin that it compares the whole list.
    cipherSpecPinsTheExactList =
      assay.eq (builtins.match ".*aes256-ctr.*aes192-ctr.*aes128-ctr.*" (builtins.head (builtins.filter (s: s.id == "V-268089") specs)).script != null) true;
  }
