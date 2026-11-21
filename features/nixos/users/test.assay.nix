# Colocated suite for features/nixos/users/test.nix — the drakkar-like users VM test (GH-187).
#
# Evaluates the test's node in each mode (no VM is booted here;
# `nix build .#checks.x86_64-linux.users-vm-<mode>` runs it), so these claims pin what the
# machine under test is: which manager writes /etc/passwd at boot and after the switch, a
# root that carries the module's lock rather than the test framework's empty password, and
# the operator's real login shell.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  testFor = mode: import ./test.nix {inherit pkgs mode;};
  perl = (testFor "perl").nodes.machine;
  userborn = (testFor "userborn").nodes.machine;
  migrate = (testFor "migrate").nodes.machine;
  added = m: m.specialisation.added.configuration;
in
  assay.suite "users-vm-test" {
    named = assay.eq (testFor "userborn").name "vm-test-run-users-vm-userborn";
    perlBootsOnPerl = assay.eq perl.services.userborn.enable false;
    perlStaysOnPerl = assay.eq (added perl).services.userborn.enable false;
    userbornBootsOnUserborn = assay.eq userborn.services.userborn.enable true;
    migrateBootsOnPerl = assay.eq migrate.services.userborn.enable false;
    migrateSwitchesToUserborn = assay.eq (added migrate).services.userborn.enable true;
    switchAddsUserAndGroup =
      assay.eq [((added userborn).users.users ? extra) ((added userborn).users.groups ? extragrp)] [true true];
    rootCarriesTheLock = assay.eq [userborn.users.users.root.hashedPassword userborn.users.users.root.hashedPasswordFile] ["!" null];
    operatorLogsIntoNushell = assay.eq (pkgs.lib.getName userborn.users.users.tom.shell) "nushell";
    mutableUsersStaysFleetDefault = assay.eq userborn.users.mutableUsers true;
  }
