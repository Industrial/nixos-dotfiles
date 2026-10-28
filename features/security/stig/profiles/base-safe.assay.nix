# Colocated suite: the base-safe profile imports exactly the controls it claims.
#
# The point of asserting the import list is that membership here is a policy decision from
# docs/security/stig-triage.md, not an implementation detail — a control silently appearing
# or disappearing from the host-wide profile is the regression this catches.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./base-safe.nix {};
  manifest = import ./../lib/manifest.nix;

  baseName = p: builtins.baseNameOf (toString p);
  imported = map baseName mod.imports;
  controlNames = builtins.filter (n: builtins.match "V-[0-9]+\\.nix" n != null) imported;
  idOf = n: builtins.head (builtins.match "(V-[0-9]+)\\.nix" n);

  deferred = mod.security.stig.deferredVerification;

  # Ids classified `base` by bin/stig-triage-gen, read back out of the generated table so the
  # profile and the triage document cannot disagree.
  triage = builtins.readFile ./../../../../docs/security/stig-triage.md;
  baseClassified =
    map (m: builtins.head m)
    (builtins.filter (m: m != null)
      (map (line: builtins.match "^\\| `(V-[0-9]+)` \\| CAT [IV]+ \\|.*\\| `base` \\|.*$" line)
        (builtins.filter builtins.isString (builtins.split "\n" triage))));
in
  assay.suite "stig-profile-base-safe" {
    declaresBaselineInEffect = assay.eq mod.security.stig.enable true;
    declaresProfileName = assay.eq mod.security.stig.profile "base-safe";

    # Option surface plus groups 1, 2a and 2b. Update deliberately when a group lands.
    importsOptionSurface = assay.eq (builtins.elem "default.nix" imported) true;
    controlCount = assay.eq (builtins.length controlNames) 68;

    # Wave 1 is complete when the profile carries every control the triage table classifies
    # `base`. This is the leaf's real exit criterion, asserted rather than counted by hand.
    carriesEveryBaseClassifiedControl = assay.eq (builtins.filter (id: !builtins.elem "${id}.nix" controlNames) baseClassified) [];

    # Every imported control id is one the manifest acknowledges — a typo'd filename would
    # otherwise import nothing and pass unnoticed.
    everyControlIsInTheManifest = assay.eq (builtins.all (n: builtins.elem (idOf n) manifest.ids) controlNames) true;

    # Classification agreement: every control in the host-wide profile must be classified
    # `base` in docs/security/stig-triage.md. This is what stops a disruptive control from
    # drifting onto the four desktops.
    everyControlIsClassifiedBase = assay.eq (builtins.filter (n: !builtins.elem (idOf n) baseClassified) controlNames) [];

    # No control is imported twice.
    noDuplicates = assay.eq (builtins.length (builtins.attrNames (builtins.listToAttrs (map (n: {
        name = n;
        value = true;
      })
      imported))))
    69;

    # Deferred-verification registry: every entry names a control that is actually imported,
    # and carries a written reason. An entry for an unimported control would be a lie in the
    # report; an empty reason would be useless to an assessor.
    deferredEntriesAreImported = assay.eq (builtins.all (id: builtins.elem "${id}.nix" controlNames) (builtins.attrNames deferred)) true;
    deferredReasonsAreWritten = assay.eq (builtins.all (id: builtins.stringLength deferred.${id} > 20) (builtins.attrNames deferred)) true;
    deferredCount = assay.eq (builtins.length (builtins.attrNames deferred)) 7;

    # Every import resolves to a file that exists, and every control is classified `base` in
    # docs/security/stig-triage.md. The second half is what stops a disruptive control from
    # drifting into the host-wide profile.
    everyImportExists = assay.eq (builtins.all (p: builtins.pathExists p) mod.imports) true;

    # No two audit controls may emit an identical rule: `security.audit.rules` is a list, so a
    # duplicate would be loaded twice (and auditctl may reject it, failing the whole unit).
    # V-268148 exists precisely because its fix text duplicates V-268091's.
    auditRulesAreUnique = let
      # Stub args wide enough for every control shape: most take `{...}`, V-268131 needs
      # config + lib for its assertion.
      stub = {
        config.environment.systemPackages = [];
        lib = (import <nixpkgs> {}).lib;
        pkgs = {};
      };
      controlFiles = builtins.filter (p: builtins.match ".*V-[0-9]+\\.nix" (toString p) != null) mod.imports;
      rulesOf = p: (import p stub).security.audit.rules or [];
      allRules = builtins.concatLists (map rulesOf controlFiles);
    in
      assay.eq (builtins.length allRules) (builtins.length (builtins.attrNames (builtins.listToAttrs (map (r: {
          name = r;
          value = true;
        })
        allRules))));
  }
