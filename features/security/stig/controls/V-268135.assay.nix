# Colocated suite: V-268135 — interactive accounts have unique UIDs.
#
# The fix text is prose about hand-editing /etc/passwd, which is meaningless on NixOS. This
# control turns it into an eval-time assertion, so both directions have to be exercised:
# distinct UIDs pass, a collision fails and names the accounts.
let
  assay = import ./../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  control = users:
    import ./V-268135.nix {
      lib = nixpkgsLib;
      config.users = {inherit users;};
    };

  verdict = mod: (builtins.head mod.assertions).assertion;
  message = mod: (builtins.head mod.assertions).message;

  distinct = control {
    tom = {
      isNormalUser = true;
      uid = 1000;
    };
    guest = {
      isNormalUser = true;
      uid = 1001;
    };
  };
  collision = control {
    tom = {
      isNormalUser = true;
      uid = 1000;
    };
    impostor = {
      isNormalUser = true;
      uid = 1000;
    };
  };
  # System users are out of scope: the requirement is about interactive accounts.
  systemUsersShareNothing = control {
    tom = {
      isNormalUser = true;
      uid = 1000;
    };
    svc = {
      isNormalUser = false;
      uid = 1000;
    };
  };
  # An account with no explicit uid is allocated one by nixpkgs and cannot collide here.
  unallocated = control {
    tom = {
      isNormalUser = true;
      uid = null;
    };
    other = {
      isNormalUser = true;
      uid = null;
    };
  };
in
  assay.suite "stig-V-268135" {
    distinctUidsPass = assay.eq (verdict distinct) true;
    duplicateUidsFail = assay.eq (verdict collision) false;

    # The message must name both accounts and the shared UID, or the finding is unactionable.
    messageNamesBothAccounts =
      assay.eq (builtins.match ".*tom=1000.*" (message collision) != null && builtins.match ".*impostor=1000.*" (message collision) != null) true;
    messageExplainsWhyItMatters =
      assay.eq (builtins.match ".*attributed to a person.*" (message collision) != null) true;

    ignoresSystemUsers = assay.eq (verdict systemUsersShareNothing) true;
    ignoresUnallocatedUids = assay.eq (verdict unallocated) true;
  }
