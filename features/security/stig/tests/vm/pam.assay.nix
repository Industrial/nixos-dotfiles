# Colocated suite: the PAM enforcement VM specs.
let
  assay = import ./../../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  harness = import ./harness.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };
  specs = import ./pam.nix {
    lib = nixpkgsLib;
    pkgs = {};
  };

  manifest = import ./../../lib/manifest.nix;
  ids = map (s: s.id) specs;
  specOf = id: builtins.head (builtins.filter (s: s.id == id) specs);
  has = id: text: nixpkgsLib.hasInfix text (specOf id).script;
  imports = id: name: builtins.any (m: builtins.baseNameOf (toString m) == name) (specOf id).modules;
in
  assay.suite "stig-vm-pam" {
    allSpecsWellFormed = assay.eq (builtins.concatLists (map harness.specProblems specs)) [];
    everyIdIsInTheManifest = assay.eq (builtins.all (id: builtins.elem id manifest.ids) ids) true;
    coversBothPamControls = assay.eq ids ["V-268081" "V-268170"];

    everySpecBootsTheRealProfileAndTheControl =
      assay.eq (map (id: [(imports id "base-safe.nix") (imports id "${id}.nix")]) ids) [[true true] [true true]];
    # Without minlen 15 the length case would test libpwquality's default, not the benchmark.
    qualitySpecCarriesTheLengthControl = assay.eq (imports "V-268170" "V-268134.nix") true;

    # These two controls once rendered a PAM line that did nothing, and a spec that only read
    # /etc/pam.d would have passed. Each of the following pins a behavioural assertion.

    # --- V-268081 ---
    lockoutTypesAtARealConsole = assay.eq (has "V-268081" "machine.send_chars(password") true;
    lockoutRefusesTheCorrectPassword =
      assay.eq (has "V-268081" "The account is now locked: the CORRECT password is refused") true;
    lockoutReadsTheTally = assay.eq (has "V-268081" "faillock --user") true;
    lockoutProvesTheResetOnSuccess = assay.eq (has "V-268081" "a successful logon did not clear the tally") true;
    lockoutProvesOthersAreUnaffected = assay.eq (has "V-268081" "accepted(4, \"bob\"") true;
    lockoutProvesRootCanRelease = assay.eq (has "V-268081" "faillock --user mallory --reset") true;
    # The decision recorded in the control: a key logon is neither blocked nor a reset.
    lockoutProvesKeyLogonIsNotBlocked = assay.eq (has "V-268081" "id -un\").strip() == \"mallory\"") true;
    lockoutProvesKeyLogonDoesNotClear = assay.eq (has "V-268081" "a key logon changed the tally") true;

    # --- V-268170 ---
    qualityRunsTheRealPasswd = assay.eq (has "V-268170" "su {user} -c passwd") true;
    qualityRefusesWeakPasswords = assay.eq (has "V-268170" "assert status != 0") true;
    qualityProvesTheStoredHashIsUnchanged = assay.eq (has "V-268170" "shadow(\"changer\") == original") true;
    qualityAcceptsACompliantPassword = assay.eq (has "V-268170" "passwd refused a compliant password") true;
    qualityCoversLengthClassesAndDictionary =
      assay.eq (map (has "V-268170") ["shorter than 15 characters" "no special character" "a dictionary word"]) [true true true];
    # Root is warned and not refused; that scope is pinned, not assumed.
    qualityPinsTheRootPath = assay.eq (has "V-268170" "pam_pwquality was not consulted by chpasswd") true;
    qualityProvesSudoStillAuthenticates = assay.eq (has "V-268170" "sudo -S -k id -un") true;
  }
