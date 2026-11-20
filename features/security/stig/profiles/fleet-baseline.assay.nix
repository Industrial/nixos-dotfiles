# Colocated suite: the fleet-baseline profile (ADR-0007).
#
# Three properties make it safe to put on every host:
#   1. it is a strict subset of base-safe, so mimir (which imports both) is unchanged
#   2. it carries none of the controls ADR-0007 excludes for their cost on a workstation
#   3. the merged result on a fleet-baseline + base-safe host is base-safe's, not a mixture
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  manifest = import ./../lib/manifest.nix;
  inherit (import <nixpkgs> {}) lib;

  fleet = import ./fleet-baseline.nix {inherit lib;};
  baseSafe = import ./base-safe.nix {};

  baseName = p: builtins.baseNameOf (toString p);
  controlsOf = mod: builtins.filter (n: builtins.match "V-[0-9]+\\.nix" n != null) (map baseName mod.imports);
  idOf = n: builtins.head (builtins.match "(V-[0-9]+)\\.nix" n);

  fleetControls = controlsOf fleet;
  baseSafeControls = controlsOf baseSafe;

  # Excluded by ADR-0007, each for a named interactive or operational cost.
  excluded = [
    "V-268080" # auditd: the ADR-0004 cost
    "V-268091" # privileged-command auditing
    "V-268095" # rename/unlink auditing
    "V-268098" # denied open auditing
    "V-268089" # STIG cipher list (weaker than nixpkgs default)
    "V-268157" # STIG MAC list (weaker than nixpkgs default)
    "V-268130" # SHA512 (downgrade from yescrypt)
    "V-268085" # maxlogins 10 (parallel deploy/build sessions)
    "V-268181" # UMASK 077 (shared group dirs)
    "V-268126" # pwquality
    "V-268171" # FAIL_DELAY
  ];

  alone = fixture.evalWith [./fleet-baseline.nix];
  # What mimir evaluates to once profiles/base.nix imports this file: both profiles.
  both = fixture.evalWith [./fleet-baseline.nix ./base-safe.nix];
in
  assay.suite "stig-profile-fleet-baseline" {
    importsOptionSurface = assay.eq (builtins.elem "default.nix" (map baseName fleet.imports)) true;
    controlCount = assay.eq (builtins.length fleetControls) 15;
    everyImportExists = assay.eq (builtins.all builtins.pathExists fleet.imports) true;
    everyControlIsInTheManifest = assay.eq (builtins.all (n: builtins.elem (idOf n) manifest.ids) fleetControls) true;

    # 1. Subset of base-safe.
    subsetOfBaseSafe = assay.eq (builtins.filter (n: !builtins.elem n baseSafeControls) fleetControls) [];

    # 2. No excluded control slipped in.
    carriesNoExcludedControl = assay.eq (builtins.filter (n: builtins.elem (idOf n) excluded) fleetControls) [];
    noAuditOnItsOwn = assay.eq alone.security.audit.enable false;
    noStigCipherPin =
      assay.eq (builtins.elem "chacha20-poly1305@openssh.com" alone.services.openssh.settings.Ciphers) true;

    # Alone: it reports as itself and credits exactly its own controls.
    aloneProfile = assay.eq alone.security.stig.profile "fleet-baseline";
    aloneImplemented = assay.eq (builtins.length alone.security.stig.implemented) 15;
    aloneEnabled = assay.eq alone.security.stig.enable true;
    aloneEvaluatesCleanly = assay.eq (builtins.filter (a: !a.assertion) alone.assertions) [];
    appliesSysctls = assay.eq [
      alone.boot.kernel.sysctl."kernel.kptr_restrict"
      alone.boot.kernel.sysctl."kernel.randomize_va_space"
      alone.boot.kernel.sysctl."net.ipv4.tcp_syncookies"
    ] [1 2 1];
    clientAlive = assay.eq [
      alone.services.openssh.settings.ClientAliveInterval
      alone.services.openssh.settings.ClientAliveCountMax
    ] [600 1];

    # 3. Together with base-safe (mimir): base-safe wins, with no duplicates and no mixing.
    bothProfileIsBaseSafe = assay.eq both.security.stig.profile "base-safe";
    bothImplementedIsBaseSafe = assay.eq both.security.stig.implemented baseSafe.security.stig.implemented;
    bothKeepsStigCiphers = assay.eq both.services.openssh.settings.Ciphers ["aes256-ctr" "aes192-ctr" "aes128-ctr"];
    bothAuditOn = assay.eq both.security.audit.enable true;
  }
