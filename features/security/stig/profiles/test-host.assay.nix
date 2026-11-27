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

  inherit (mod.security) stig;
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
    # The 16 are drawn from the `full` set, and are pinned so that adding or dropping one is
    # a deliberate edit here and in ADR-0008.
    addsOnlyControlsFromFull = assay.eq (builtins.filter (id: !builtins.elem id fullOnlyIds) ownIds) [];
    addsExactlyTheSixteen =
      assay.eq (sorted ownIds)
      [
        "V-268081"
        "V-268082"
        "V-268083"
        "V-268084"
        "V-268086"
        "V-268101"
        "V-268102"
        "V-268133"
        "V-268134"
        "V-268135"
        "V-268136"
        "V-268152"
        "V-268155"
        "V-268170"
        "V-268172"
        "V-268174"
      ];
    carriesEightyFour = assay.eq (builtins.length carried) 84;
    # mkForce-wrapped, because base-safe also labels the profile.
    declaresProfileName = assay.eq stig.profile.content "test-host";
    overridesTheBaseLabel = assay.eq (stig.profile._type or null) "override";
    everyImportExists = assay.eq (builtins.all builtins.pathExists mod.imports) true;
    # Nothing excluded has a reboot to wait for, and none of the 16 is a kernel parameter:
    # both registries are base-safe's, untouched.
    addsNoRebootOrDeferredEntries = assay.eq [(stig ? requiresReboot) (stig ? deferredVerification)] [false false];

    # --- the exclusions must be justified, not blank ---
    excludesEighteen = assay.eq (builtins.length excluded) 18;
    everyExclusionIsJustified =
      assay.eq (builtins.filter (id: builtins.stringLength stig.exclude.${id} <= 80) excluded) [];
    # The three procedural controls carry the shared text, so `full` and this profile give an
    # assessor the same reason.
    proceduralExclusionsAreShared =
      assay.eq (lib.filterAttrs (id: _: procedural ? ${id}) stig.exclude) procedural;
    # The 15 that are not procedural say that they were not applied.
    hostExclusionsSayNotApplied =
      assay.eq (builtins.filter (id: !(procedural ? ${id}) && builtins.match "Not applied.*" stig.exclude.${id} == null) excluded) [];
    # Exclusions that wait on the owner say so in the text an assessor reads.
    ownerDecisionsAreMarked =
      assay.eq (map (id: builtins.match ".*(owner|#340).*" stig.exclude.${id} != null) ["V-268147" "V-268139" "V-268138"]) [true true true];
    # V-268081 and V-268170 sat in `exclude` while their modules rendered a PAM line that
    # enforced nothing (ADR-0008, decision 4). They are carried now, and the condition that
    # decision set is pinned here: each has a VM spec, and tests/vm/pam.assay.nix pins that
    # the spec asserts what the machine refuses, not what /etc/pam.d contains.
    pamControlsAreCarried =
      assay.eq [(builtins.filter (id: !builtins.elem id ownIds) ["V-268081" "V-268170"]) (builtins.filter (id: stig.exclude ? ${id}) ["V-268081" "V-268170"])] [[] []];
    pamControlsHaveAVmSpec =
      assay.eq (builtins.filter (id: !builtins.elem id (map (s: s.id) (import ./../tests/vm/pam.nix {}))) ["V-268081" "V-268170"]) [];
    # ... and a gate on this host's own configuration (flake check stig-test-host-logon; its
    # node and script are pinned by ../tests/test-host-logon.assay.nix).
    testHostLogonGateExists = assay.eq (builtins.pathExists ./../tests/test-host-logon.nix) true;
    # V-268132 is excluded under the same decision, and stays excluded while nothing enforces
    # it: the text names what was observed, and tests/vm/test-host.nix pins each observation.
    unenforcedMinimumAgeIsNotCarried =
      assay.eq [(builtins.elem "V-268132" carried) (stig.exclude ? "V-268132")] [false true];
    unenforcedMinimumAgeExclusionSaysWhatWasObserved = assay.eq (map (needle: lib.hasInfix needle stig.exclude."V-268132") [
      "the published check, a grep of that file, passes"
      "shadow 4.20.3 no longer implements the setting"
      "chage has no --mindays"
      "'password updated successfully' and exits 0"
      "stig-V-268132"
    ]) [true true true true true];
    # The pwquality.conf settings V-268170 makes PAM apply are all carried with it.
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
