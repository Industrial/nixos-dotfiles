# Colocated suite: the full profile covers all 103 controls and stays off the workstations.
#
# Two invariants carry this suite. Completeness — every control in the benchmark is accounted
# for by exactly one of implemented / excluded / satisfiedExternally — and containment: no
# host may import this profile, because it would make the machine unusable.
let
  assay = import ./../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;
  mod = import ./full.nix {lib = nixpkgsLib;};
  baseSafe = import ./base-safe.nix {};
  manifest = import ./../lib/manifest.nix;

  stig = mod.security.stig;
  baseIds = baseSafe.security.stig.implemented;
  fullIds = stig.implemented;
  excluded = builtins.attrNames stig.exclude;
  external = builtins.attrNames baseSafe.security.stig.satisfiedExternally;

  accountedFor = baseIds ++ fullIds ++ excluded ++ external;

  baseName = p: builtins.baseNameOf (toString p);
  imported = map baseName mod.imports;

  hostConfigs = ["drakkar" "huginn" "mimir" "muninn"];
  hostImportsFull = host:
    builtins.match ".*full\\.nix.*" (builtins.readFile (./../../../../hosts + "/${host}/configuration.nix")) != null;
in
  assay.suite "stig-profile-full" {
    # --- completeness ---
    # Every control in the benchmark is accounted for exactly once.
    everyControlIsAccountedFor =
      assay.eq (builtins.filter (id: !builtins.elem id accountedFor) manifest.ids) [];
    accountsForNothingExtra =
      assay.eq (builtins.filter (id: !builtins.elem id manifest.ids) accountedFor) [];
    noControlIsCountedTwice = assay.eq (builtins.length accountedFor) (builtins.length (builtins.attrNames (builtins.listToAttrs (map (id: {
        name = id;
        value = true;
      })
      accountedFor))));
    totalIs103 = assay.eq (builtins.length accountedFor) 103;

    # The full profile adds exactly the controls base-safe lacks.
    addsOnlyWhatBaseSafeLacks =
      assay.eq (builtins.filter (id: builtins.elem id baseIds) fullIds) [];
    # mkForce-wrapped, because base-safe also labels the profile and the narrower definition
    # has to win. Read through the wrapper rather than asserting the raw value.
    declaresProfileName = assay.eq stig.profile.content "full";
    overridesTheBaseLabel = assay.eq (stig.profile._type or null) "override";
    buildsOnBaseSafe = assay.eq (builtins.elem "base-safe.nix" imported) true;

    # --- containment: this profile must never reach a workstation ---
    noHostImportsFullProfile = assay.eq (builtins.filter hostImportsFull hostConfigs) [];

    # --- the exclusions must be justified, not blank ---
    excludedControlsAreJustified =
      assay.eq (builtins.all (id: builtins.stringLength stig.exclude.${id} > 40) excluded) true;
    excludesOnlyProceduralControls = assay.eq (builtins.sort (a: b: a < b) excluded) ["V-268079" "V-268125" "V-268180"];
    # The emergency-account exclusion must say it has to be revisited, since it is only true
    # while no such account exists.
    emergencyAccountExclusionIsConditional =
      assay.eq (builtins.match ".*re-asserted.*" stig.exclude."V-268079" != null) true;
    # Each exclusion says WHY, in terms of what cannot be configured.
    keyPassphraseExclusionExplainsItself =
      assay.eq (builtins.match ".*[Pp]rocedural.*" stig.exclude."V-268125" != null) true;

    # --- reboot-dependent controls are registered ---
    # fips is a kernel parameter; without this the report would claim compliance on a target
    # that had only switched.
    fipsRequiresReboot = assay.eq (stig.requiresReboot ? "V-268168") true;
    fipsReasonMentionsTheKernelCommandLine =
      assay.eq (builtins.match ".*kernel command line.*" stig.requiresReboot."V-268168" != null) true;

    # --- every import resolves ---
    everyImportExists = assay.eq (builtins.all (p: builtins.pathExists p) mod.imports) true;
  }
