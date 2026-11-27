# Colocated suite: the VM specs for the 15 controls the test-host profile adds to base-safe.
let
  assay = import ./../../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  harness = import ./harness.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };
  specs = import ./test-host.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };

  manifest = import ./../../lib/manifest.nix;
  banner = import ./../../lib/dow-banner.nix;
  ids = map (s: s.id) specs;
  pamIds = map (s: s.id) (import ./pam.nix {});
  specOf = id: builtins.head (builtins.filter (s: s.id == id) specs);
  scriptHas = id: pattern: builtins.match ".*${pattern}.*" (specOf id).script != null;

  # The profile's own controls, read off its import list, so the spec list is compared with
  # what muninn carries and not with a second hand-kept copy.
  testHost = import ./../../profiles/test-host.nix {lib = nixpkgsLib;};
  profileControls =
    map (n: builtins.head (builtins.match "(V-[0-9]+)\\.nix" n))
    (builtins.filter (n: builtins.match "V-[0-9]+\\.nix" n != null)
      (map (p: builtins.baseNameOf (toString p)) testHost.imports));

  # The expected banner is embedded in each banner script as a JSON list.
  bannerJson = builtins.toJSON banner.paragraphs;
in
  assay.suite "stig-vm-test-host" {
    allSpecsWellFormed = assay.eq (builtins.concatLists (map harness.specProblems specs)) [];
    everyIdIsInTheManifest = assay.eq (builtins.all (id: builtins.elem id manifest.ids) ids) true;
    specCount = assay.eq (builtins.length specs) 15;

    # Exactly the controls the profile adds: one spec each, none missing, none for a control
    # the profile does not carry. The two that live in the PAM stacks (V-268081, V-268170)
    # have their specs in ./pam.nix, where the control is tested for what it enforces.
    #
    # One spec is for a control the profile EXCLUDES: V-268132, whose check passes while
    # nothing enforces it. That spec is the evidence for the exclusion, so it imports the
    # control's module itself, next to the profile.
    specsAreTheProfilesOwnControls =
      assay.eq (builtins.sort builtins.lessThan (ids ++ pamIds)) (builtins.sort builtins.lessThan (profileControls ++ ["V-268132"]));
    unenforcedControlIsExcludedAndStillTested = let
      mods = map (m: builtins.baseNameOf (toString m)) (specOf "V-268132").modules;
    in
      assay.eq [(builtins.elem "V-268132" profileControls) (testHost.security.stig.exclude ? "V-268132") mods] [false true ["test-host.nix" "V-268132.nix"]];
    # Its three observations are assertions, so the exclusion text cannot outlive them.
    unenforcedControlSpecPinsWhatItObserved = assay.eq (map (text: nixpkgsLib.hasInfix text (specOf "V-268132").script) [
      "assert fields[3] == \"\""
      "chage --mindays 1 stigprobe"
      "You must wait longer to change your password"
      "status == 0 and \"password updated successfully\" in out"
    ]) [true true true true];
    pamSpecsAreElsewhere = assay.eq [pamIds (builtins.filter (id: builtins.elem id ids) pamIds)] [["V-268081" "V-268170"] []];

    # Each test boots the profile muninn carries, not the control alone, so it also proves
    # the 84 controls compose into a machine that boots.
    everySpecUsesTheRealProfile =
      assay.eq (builtins.all (s: builtins.any (m: builtins.match ".*test-host\\.nix" (toString m) != null) s.modules) specs) true;

    # The banner specs compare against the notice as the CHECK text prints it, parsed from the
    # vendored benchmark. It must come out as the same seven paragraphs the controls render
    # from lib/dow-banner.nix; if the parse ever returns something else, the specs would be
    # comparing the machine against the wrong text.
    bannerExpectationIsTheChecksOwnText =
      assay.eq (map (id: nixpkgsLib.hasInfix bannerJson (specOf id).script) ["V-268082" "V-268083" "V-268084"]) [true true true];
    bannerSpecsCompareTheWholeNotice =
      assay.eq (map (id: scriptHas id "assert shown == expected") ["V-268082" "V-268083" "V-268084"]) [true true true];

    # Each banner is read where its own check reads it.
    consoleBannerReadsIssueAsTheCheckDoes = assay.eq (scriptHas "V-268082" "tail -n\\+3 /etc/issue") true;
    sshBannerIsReceivedBeforeAuthentication = assay.eq (scriptHas "V-268083" "BatchMode=yes") true;
    greeterBannerReadsTheGdmProfile = assay.eq (scriptHas "V-268084" "DCONF_PROFILE=gdm dconf read") true;

    # The graphical controls have no consumer without a greeter, so their specs must boot one.
    graphicalSpecsBootGdm = assay.eq (map (id:
      builtins.any (m: (m.services.displayManager.gdm.enable or false))
      (builtins.filter builtins.isAttrs ((specOf id).extraModules or []))) ["V-268084" "V-268172"]) [true true];

    # Settings in a file are also asked of the daemon that reads the file.
    idleLockIsReadFromLogind = assay.eq (scriptHas "V-268086" "busctl get-property") true;
    # The dconf key is locked, and a user's own write is shown not to take.
    idleDelayLockIsAsserted = assay.eq [(scriptHas "V-268086" "dconf list-locks") (scriptHas "V-268086" "after a user's write, idle-delay reads")] [true true];
    sudoTimeoutIsReadFromSudo = assay.eq (scriptHas "V-268155" "sudo -V") true;
    sudoTimeoutIsExercised = assay.eq (scriptHas "V-268155" "sudo -S .*! sudo -n true") true;
    nixDaemonRefusalIsExercised = assay.eq (scriptHas "V-268152" "not allowed to connect to the Nix daemon") true;

    # V-268155 has to win against the fleet's own never-expire line, so the spec must put
    # that line in the file it tests.
    sudoSpecReproducesTheFleetsLine =
      assay.eq (builtins.any (m:
        builtins.isFunction m
        && nixpkgsLib.hasInfix "timestamp_timeout=-1" (m {lib = nixpkgsLib;}).security.sudo.extraConfig.content)
      (specOf "V-268155").extraModules)
      true;

    # login.defs and /etc/default/useradd are defaults for new accounts; the three specs
    # that depend on them must create one and read its shadow entry.
    agingSpecsCreateAnAccount =
      assay.eq (map (id: scriptHas id "useradd --create-home stigprobe") ["V-268132" "V-268133" "V-268174"]) [true true true];

    # The published check for V-268086 has a third leg the control deliberately does not
    # meet. The spec must say so in the open rather than skip it.
    xautolockGapIsStated = assay.eq (scriptHas "V-268086" "machine\\.fail\\(\"test -e /etc/systemd/user/xautolock\\.service\"\\)") true;

    # The two assertion controls cannot be shown refusing a configuration from inside a VM
    # that booted. Their specs run the runtime half and point at the suite with the refusal.
    assertionSpecsPointAtTheEvalProof = assay.eq [
      (scriptHas "V-268135" "controls/V-268135\\.assay\\.nix")
      (scriptHas "V-268172" "controls/V-268172\\.assay\\.nix")
    ] [true true];
    duplicateUidSpecRunsTheChecksAwk = assay.eq (nixpkgsLib.hasInfix "'list[$3]++{print $1, $3}' /etc/passwd" (specOf "V-268135").script) true;
    autologinSpecLooksForAUserSession = assay.eq (scriptHas "V-268172" "cls != \"user\"") true;
  }
