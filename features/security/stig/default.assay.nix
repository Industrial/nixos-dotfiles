# Colocated suite: the STIG option surface declares what the report depends on.
let
  assay = import ./../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;
  fixture = import ./lib/fixture.nix;

  # default.nix now also has a `config` section (it renders pwquality.conf), so it needs both
  # arguments. The stub config only has to satisfy what that section reads.
  mod = import ./default.nix {
    lib = nixpkgsLib;
    config.security.stig.pwquality = {};
  };
  opts = mod.options.security.stig;
in
  assay.suite "stig-options" {
    enableDefaultsOff = assay.eq opts.enable.default false;
    enableIsBool = assay.eq opts.enable.type.name "bool";

    profileDefaultsNone = assay.eq opts.profile.default "none";
    profileAcceptsBaseSafe = assay.eq (opts.profile.type.check "base-safe") true;
    profileAcceptsFull = assay.eq (opts.profile.type.check "full") true;
    profileRejectsUnknown = assay.eq (opts.profile.type.check "hardened") false;

    # Unverifiable-by-eval controls must be declarable, so "systemd does it by default" cannot
    # masquerade as a proven control in the report.
    deferredDefaultsEmpty = assay.eq opts.deferredVerification.default {};
    deferredAcceptsReasons = assay.eq (opts.deferredVerification.type.check {"V-268117" = "runtime only";}) true;
    deferredRejectsBareList = assay.eq (opts.deferredVerification.type.check ["V-268117"]) false;

    excludeDefaultsEmpty = assay.eq opts.exclude.default {};
    # id -> written justification; the report renders these as Not Applicable with the reason.
    excludeAcceptsJustifications = assay.eq (opts.exclude.type.check {"V-268079" = "no such accounts";}) true;
    excludeRejectsBareList = assay.eq (opts.exclude.type.check ["V-268079"]) false;

    # pwquality aggregation: six controls share one file, so the option must accept their
    # keys and the renderer must only fire when something was contributed.
    pwqualityDefaultsEmpty = assay.eq opts.pwquality.default {};
    pwqualityAcceptsInts = assay.eq (opts.pwquality.type.check {ucredit = -1;}) true;
    pwqualityAcceptsStrings = assay.eq (opts.pwquality.type.check {badwords = "nixos";}) true;

    # No pwquality.conf is emitted when no control contributed a setting — otherwise a host
    # without the password group would get an empty config file.
    noFileWhenEmpty = assay.eq (builtins.hasAttr "security/pwquality.conf" (fixture.evalWith [./default.nix]).environment.etc) false;
    fileAppearsWhenContributed = assay.eq (builtins.hasAttr "security/pwquality.conf" (fixture.evalWith [./default.nix ./controls/V-268126.nix]).environment.etc) true;
  }
