# Colocated suite: the test-host profile accounts for all 103 controls and is on muninn only.
#
# Three invariants. Completeness — every control in the benchmark is configured, excluded or
# satisfied externally, exactly once. Justification — every exclusion carries a written
# reason. Containment — no host but muninn switches the profile on (ADR-0008).
let
  assay = import ./../../../../common/assay/default.nix;
  nixos = import ./../../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  features = import ./../../../../lib/features.nix {inherit lib;};

  mod = import ./test-host.nix {inherit lib;};
  baseSafe = import ./base-safe.nix {};
  full = import ./full.nix {inherit lib;};
  # Read from the same file profiles/base.nix enables, as full.assay.nix does.
  externalEvidence = import ./external-evidence.nix {};
  procedural = import ./../lib/procedural-exclusions.nix;
  manifest = import ./../lib/manifest.nix;

  stig = mod.security.stig;
  baseIds = baseSafe.security.stig.implemented;
  ownIds = stig.implemented;
  fullOnlyIds = full.security.stig.implemented;
  excluded = builtins.attrNames stig.exclude;
  external = builtins.attrNames externalEvidence.security.stig.satisfiedExternally;

  carried = baseIds ++ ownIds;
  accountedFor = carried ++ excluded ++ external;

  unique = ids: builtins.attrNames (lib.genAttrs ids (_: true));
  sorted = builtins.sort (a: b: a < b);
  baseName = p: builtins.baseNameOf (toString p);

  otherHosts = ["drakkar" "huginn" "mimir"];
  enablesTestHost = host:
    builtins.elem "security.stig.profiles.test-host" (features.enabledFeatures (features.evalSelection {
      modules = [
        (./../../../../hosts + "/${host}/configuration.nix")
        {
          disabledModules = map (f: ./../../../../hosts + "/${host}/${f}") ["disko.nix" "filesystems.nix" "hardware.nix"];
        }
      ];
    }));
in
  assay.suite "stig-profile-test-host" {
    # --- completeness, of the profile as written ---
    everyCarriedIdIsInTheManifest =
      assay.eq (builtins.filter (id: !builtins.elem id manifest.ids) accountedFor) [];
    everyControlIsAccountedFor =
      assay.eq (builtins.filter (id: !builtins.elem id accountedFor) manifest.ids) [];
    noControlIsCountedTwice = assay.eq (builtins.length accountedFor) (builtins.length (unique accountedFor));
    noControlIsBothImplementedAndExcluded =
      assay.eq (builtins.filter (id: builtins.elem id carried) excluded) [];
    totalIs103 = assay.eq (builtins.length accountedFor) 103;

    # --- composition ---
    buildsOnBaseSafe = assay.eq (builtins.elem "base-safe.nix" (map baseName mod.imports)) true;
    addsOnlyWhatBaseSafeLacks = assay.eq (builtins.filter (id: builtins.elem id baseIds) ownIds) [];
    # The 15 are drawn from the `full` set, and are pinned so that adding or dropping one is
    # a deliberate edit here and in ADR-0008.
    addsOnlyControlsFromFull = assay.eq (builtins.filter (id: !builtins.elem id fullOnlyIds) ownIds) [];
    addsExactlyTheFifteen =
      assay.eq (sorted ownIds)
      [
        "V-268082"
        "V-268083"
        "V-268084"
        "V-268086"
        "V-268101"
        "V-268102"
        "V-268132"
        "V-268133"
        "V-268134"
        "V-268135"
        "V-268136"
        "V-268152"
        "V-268155"
        "V-268172"
        "V-268174"
      ];
    carriesEightyThree = assay.eq (builtins.length carried) 83;
    # mkForce-wrapped, because base-safe also labels the profile.
    declaresProfileName = assay.eq stig.profile.content "test-host";
    overridesTheBaseLabel = assay.eq (stig.profile._type or null) "override";
    everyImportExists = assay.eq (builtins.all builtins.pathExists mod.imports) true;
    # Nothing excluded has a reboot to wait for, and none of the 15 is a kernel parameter:
    # both registries are base-safe's, untouched.
    addsNoRebootOrDeferredEntries = assay.eq [(stig ? requiresReboot) (stig ? deferredVerification)] [false false];

    # --- the exclusions must be justified, not blank ---
    excludesNineteen = assay.eq (builtins.length excluded) 19;
    everyExclusionIsJustified =
      assay.eq (builtins.filter (id: builtins.stringLength stig.exclude.${id} <= 80) excluded) [];
    # The three procedural controls carry the shared text, so `full` and this profile give an
    # assessor the same reason.
    proceduralExclusionsAreShared =
      assay.eq (lib.filterAttrs (id: _: procedural ? ${id}) stig.exclude) procedural;
    # The 16 that are not procedural say that they were not applied.
    hostExclusionsSayNotApplied =
      assay.eq (builtins.filter (id: !(procedural ? ${id}) && builtins.match "Not applied.*" stig.exclude.${id} == null) excluded) [];
    # Exclusions that wait on the owner say so in the text an assessor reads.
    ownerDecisionsAreMarked =
      assay.eq (map (id: builtins.match ".*(owner|#340).*" stig.exclude.${id} != null) ["V-268147" "V-268139" "V-268138"]) [true true true];
    # Two control modules render a PAM line that does not enforce the requirement (ADR-0008).
    # They are excluded, not carried, so the report cannot call them compliant; each text
    # names the defect and says the control returns with a reworked module and a VM test.
    nonEnforcingPamControlsAreNotCarried =
      assay.eq (builtins.filter (id: builtins.elem id carried) ["V-268081" "V-268170"]) [];
    nonEnforcingPamExclusionsNameTheDefect = assay.eq [
      (builtins.match ".*preauth, authfail or authsucc.*never records.*" stig.exclude."V-268081" != null)
      (builtins.match ".*after a 'sufficient' pam_unix.so.*never reached.*" stig.exclude."V-268170" != null)
    ] [true true];
    nonEnforcingPamExclusionsSayWhenTheyReturn =
      assay.eq (map (id: builtins.match ".*reworked and has a VM test.*" stig.exclude.${id} != null) ["V-268081" "V-268170"]) [true true];
    # The pwquality.conf settings stay configured; the V-268170 text says PAM does not
    # enforce them yet, so their "compliant" rows are not read as enforcement.
    pwqualityExclusionSaysSettingsAreNotEnforced =
      assay.eq (builtins.match ".*V-268126.*V-268134.*V-268169.*PAM does not enforce them.*" stig.exclude."V-268170" != null) true;
    pwqualitySettingsStayCarried =
      assay.eq (builtins.filter (id: !builtins.elem id carried) ["V-268126" "V-268127" "V-268128" "V-268129" "V-268134" "V-268145" "V-268169"]) [];
    # The site-input controls are excluded, not carried: carried without their inputs they
    # are failing assertions, and muninn would not build.
    siteInputControlsAreExcluded =
      assay.eq (builtins.filter (id: !(stig.exclude ? ${id})) ["V-268108" "V-268109" "V-268124" "V-268139" "V-268153" "V-268178"]) [];
    # The controls that would take the laptop off the network, off its peripherals or out of
    # its own account are not carried.
    lockoutControlsAreNotCarried =
      assay.eq (builtins.filter (id: builtins.elem id carried) ["V-268138" "V-268139" "V-268146" "V-268147" "V-268158" "V-268168" "V-268177"]) [];

    # --- containment: muninn only ---
    # That muninn itself enables it, and what its evaluated configuration then accounts for,
    # is asserted by hosts/muninn/configuration.assay.nix.
    noOtherHostEnablesIt = assay.eq (builtins.filter enablesTestHost otherHosts) [];
  }
