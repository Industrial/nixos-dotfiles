# Colocated suite: users, root lock, and the Nix daemon trust boundary (ADR-0007).
#
# Evaluates the module inside a real NixOS system (common/assay/nixos.nix, pinned to the
# flake's nixpkgs), so assertions read the merged configuration rather than the module's
# literal attrset.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;

  settings = {
    hostname = "h";
    username = "alice";
    userdir = "/home/alice";
    userfullname = "Alice";
  };

  evalWith = extra:
    nixos.eval {
      modules = [./default.nix] ++ extra;
      inherit settings;
    };

  default = evalWith [];
  signing = evalWith [
    {
      features.hardening = {
        operatorTrusted = false;
        storeSigning = {
          enable = true;
          publicKeys = ["h-1:AAAA"];
        };
      };
    }
  ];
  rootUnlocked = evalWith [{features.hardening.lockRoot = false;}];
  userborn = evalWith [{features.nixos.users.userborn.enable = true;}];
  untrustedWithoutSigning = evalWith [{features.hardening.operatorTrusted = false;}];
  signingWithoutKeys = evalWith [{features.hardening.storeSigning.enable = true;}];

  failedAssertions = config: builtins.filter (a: !a.assertion) config.assertions;
  failsWith = config: pat:
    builtins.any (a: builtins.match pat a.message != null) (failedAssertions config);
in
  assay.suite "users" {
    username = assay.eq default.users.users.alice.isNormalUser true;
    operatorIsWheel = assay.eq (builtins.elem "wheel" default.users.users.alice.extraGroups) true;
    # NFS authorises by number: uid and the data gid must be identical on every host for
    # mimir's /data ownership to mean the same user on its clients.
    nfsStableIds = assay.eq [default.users.users.alice.uid default.users.groups.data.gid] [1000 1111];

    # Root: locked by declaration, and the old "test" hash is gone.
    rootLocked = assay.eq default.users.users.root.hashedPassword "!";
    rootHasNoInitialHash = assay.eq default.users.users.root.initialHashedPassword null;
    lockScriptPresent = assay.eq (default.system.activationScripts ? lockRootPassword) true;
    lockScriptRunsAfterUsers =
      assay.eq default.system.activationScripts.lockRootPassword.deps ["users"];
    # The safety interlock: root is only locked while the operator has a real hash.
    lockScriptGuardsOperator =
      assay.eq
      (builtins.match ".*operator_hash.*usermod -L root.*" default.system.activationScripts.lockRootPassword.text != null)
      true;
    lockIsOptOut = assay.eq (rootUnlocked.system.activationScripts ? lockRootPassword) false;
    optOutLeavesRootUndeclared = assay.eq rootUnlocked.users.users.root.hashedPassword null;

    # Trust: operator stays trusted by default, because deploy-rs and remote builds need it.
    # Membership, not equality: nixpkgs' own ["root"] default merges into the list too.
    operatorTrustedByDefault =
      assay.eq (builtins.elem "alice" default.nix.settings.trusted-users) true;
    onlyWheelMayUseNix = assay.eq default.nix.settings.allowed-users ["@wheel"];
    noSigningKeyByDefault = assay.eq (default.nix.settings ? secret-key-files) false;
    defaultEvaluatesCleanly = assay.eq (failedAssertions default) [];

    # With signing on, the operator leaves trusted-users and fleet keys are trusted.
    signingDropsOperatorTrust =
      assay.eq (builtins.filter (u: u != "root") signing.nix.settings.trusted-users) [];
    signingSetsKeyFile =
      assay.eq signing.nix.settings.secret-key-files ["/var/lib/nix-signing/secret-key"];
    signingTrustsFleetKeys =
      assay.eq (builtins.elem "h-1:AAAA" signing.nix.settings.trusted-public-keys) true;
    signingEvaluatesCleanly = assay.eq (failedAssertions signing) [];

    # Interlocks that stop a deploy-breaking combination.
    untrustRequiresSigning = assay.eq (failsWith untrustedWithoutSigning ".*needs features.hardening.storeSigning.enable.*") true;
    signingRequiresKeys = assay.eq (failsWith signingWithoutKeys ".*publicKeys is empty.*") true;

    # userborn (GH-187): off by default; on, it replaces the perl script and root is still
    # locked, by the activation snippet and by a unit that runs once userborn has written
    # /etc/shadow (on a fresh boot the snippet runs first and finds no file).
    userbornOffByDefault = assay.eq default.services.userborn.enable false;
    noLockUnitByDefault = assay.eq (default.systemd.services ? lock-root-password) false;
    userbornOptIn = assay.eq userborn.services.userborn.enable true;
    userbornReplacesPerl = assay.eq userborn.system.activationScripts.users "";
    userbornKeepsLockSnippet = assay.eq (userborn.system.activationScripts ? lockRootPassword) true;
    userbornLocksAfterUserborn =
      assay.eq userborn.systemd.services.lock-root-password.after ["userborn.service"];
    lockToleratesMissingShadow =
      assay.eq (builtins.match ".*if [[] -e /etc/shadow []]; then.*" default.system.activationScripts.lockRootPassword.text != null) true;
    userbornEvaluatesCleanly = assay.eq (failedAssertions userborn) [];
  }
