# NixOS VM test for the user database on a drakkar-like host (GH-187): the operator's
# account, the locked root, operator SSH, passwordless sudo and console login, across a
# switch that adds a user and a group and a rollback. After the rollback (GH-206) it checks
# that exactly the configured login users and groups are left, what each manager does with
# the dropped user and group, and that docs/runbooks/userborn.md's manual cleanup restores
# the configured set.
#
# One test, three ways of managing /etc/{passwd,group,shadow}:
#   perl      stock update-users-groups.pl (the control; what the fleet runs today)
#   userborn  services.userborn from first boot
#   migrate   boots on perl, the switch moves to userborn, the rollback returns to perl
#             (the path drakkar would take, both ways)
#
# The node imports the same feature modules drakkar gets for users and access: users
# (ADR-0007 root lock), sudo, pam, no-defaults, network/ssh, fleet/operator-ssh and the
# nushell login shell. users.mutableUsers stays at the fleet default (true).
#
#   nix build .#checks.x86_64-linux.users-vm-userborn   (and -perl, -migrate)
{
  pkgs,
  mode,
}: let
  inherit (pkgs) lib;
  sshKeys = import (pkgs.path + "/nixos/tests/ssh-keys.nix") pkgs;
  inherit (import ../../../common/settings.nix {hostname = "machine";}) settings;
  user = settings.username;
  # features/nixos/users/default.nix's initialOperatorHash: crypt("test").
  operatorHash = "$6$jne0QlJa/oBzEapq$4/gnXjNpggz.R45ND4QYwzqOyIz9CeblnqKzfnN7njIuKZSEfweNISngx87xy6VA0bEmncyyTmiNa5Q5GXDj5/";
  privateKey = sshKeys.snakeOilPrivateKey;
  expectedGroups = ["audio" "networkmanager" "plugdev" "render" "video" "wheel" "data" "games"];
  # The user and group the switch adds and the rollback drops (GH-206).
  stray = "extra";
  strayGroup = "extragrp";

  # What the base configuration (the rollback target) should leave in /etc/{passwd,group},
  # derived from the evaluated node rather than written out by hand (GH-206).
  population = cfg: let
    users = lib.filterAttrs (_: u: u.enable) cfg.users.users;
    shellOf = u:
      if u.shell == null
      then ""
      else toString (u.shell.shellPath or u.shell);
    # The same test as the runbook's and the deploy probe's `awk -F: '$7 !~ /nologin|false/'`.
    loginCapable = u: builtins.match ".*(nologin|false).*" (shellOf u) == null;
    # The hash the manager writes: the first one set, in NixOS's order of precedence.
    # A user with none gets "!" (locked).
    hashOf = u: lib.findFirst (x: x != null) "!" [u.hashedPassword u.password u.initialHashedPassword u.initialPassword];
    unlocked = u: u.hashedPasswordFile != null || !(lib.hasPrefix "!" (hashOf u));
    names = pred: lib.sort lib.lessThan (lib.attrNames (lib.filterAttrs (_: pred) users));
  in {
    login = names loginCapable;
    active = names (u: loginCapable u && unlocked u);
    normal = names (u: u.isNormalUser);
    groups = lib.sort lib.lessThan (lib.attrNames cfg.users.groups);
  };
in
  assert lib.elem mode ["perl" "userborn" "migrate"];
    pkgs.testers.runNixOSTest ({config, ...}: {
      name = "users-vm-${mode}";
      globalTimeout = 1200;
      # What the rollback must return to (GH-206); test.assay.nix pins it.
      passthru.population = population config.nodes.machine;

      node.specialArgs = {inherit settings;};

      nodes.machine = {lib, ...}: {
        imports = [
          ./default.nix
          ../security/sudo/default.nix
          ../security/no-defaults/default.nix
          ../../security/pam/default.nix
          ../../network/ssh/default.nix
          ../../fleet/operator-ssh.nix
          ../../cli/nushell/default.nix
        ];

        features.nixos.users.userborn.enable = mode == "userborn";

        # On drakkar these come from NetworkManager and the udev/yubikey features.
        users.groups = {
          networkmanager = {};
          plugdev = {};
        };
        # The test instrumentation gives root an empty password (hashedPasswordFile, which
        # outranks hashedPassword). Drop it, so root carries exactly what drakkar declares.
        users.users.root.hashedPasswordFile = lib.mkForce null;
        # A test key next to the fleet's enrolled ones (operator-ssh.nix), so the VM can log in.
        users.users.${user}.openssh.authorizedKeys.keys = [sshKeys.snakeOilPublicKey];

        specialisation.added.configuration = {
          features.nixos.users.userborn.enable = lib.mkForce (mode != "perl");
          users = {
            groups.${strayGroup} = {};
            users.${stray} = {
              isNormalUser = true;
              extraGroups = [strayGroup];
              hashedPassword = operatorHash;
            };
            users.${user}.extraGroups = [strayGroup];
          };
        };

        virtualisation = {
          cores = 2;
          memorySize = 1536;
        };
      };

      testScript = let
        pop = config.passthru.population;
      in ''
        expected_groups = set(${builtins.toJSON expectedGroups})
        # The base configuration's population (GH-206), from the evaluated node.
        base_login = set(${builtins.toJSON pop.login})
        base_active = set(${builtins.toJSON pop.active})
        base_normal = set(${builtins.toJSON pop.normal})
        base_groups = set(${builtins.toJSON pop.groups})
        stray, stray_group = "${stray}", "${strayGroup}"
        key = "/root/operator-key"
        ssh = f"ssh -n -i {key} -o BatchMode=yes -o StrictHostKeyChecking=no -o IdentitiesOnly=yes"
        tty = [0]

        def field(db, name, n):
            line = machine.succeed(f"getent {db} {name}").strip()
            return line.split(":")[n]

        def manager():
            ub = machine.execute("systemctl is-active userborn.service")[1].strip()
            return f"userborn.service={ub}"

        def check_files(label):
            for tool in ["pwck -r", "grpck -r"]:
                rc, out = machine.execute(f"{tool} 2>&1")
                print(f"[{label}] {tool}: exit={rc}\n{out}")
                assert rc == 0, f"{tool} failed at {label}: {out}"

        def names(path):
            return {l.split(":")[0] for l in machine.succeed(f"cat {path}").splitlines() if l.strip()}

        def login_users():
            # The runbook's and the deploy probe's definition of a login-capable account.
            return set(machine.succeed("awk -F: '$7 !~ /nologin|false/ {print $1}' /etc/passwd").split())

        def active_users():
            # Login-capable, with a usable password (the shadow hash is not locked with ! or *).
            shadow = machine.succeed("cat /etc/shadow").splitlines()
            hashes = {l.split(":")[0]: l.split(":")[1] for l in shadow if l.strip()}
            return {u for u in login_users() if not hashes.get(u, "!").startswith(("!", "*"))}

        def members(group):
            m = field("group", group, 3)
            return set(m.split(",")) if m else set()

        def present(db, name):
            return machine.execute(f"getent {db} {name}")[0] == 0

        def check_population(label, login, active, groups):
            with subtest(f"[{label}] exactly the expected users and groups"):
                got = login_users()
                assert got == login, f"login-capable users {sorted(got)}, expected {sorted(login)}"
                got = active_users()
                assert got == active, f"active users {sorted(got)}, expected {sorted(active)}"
                got = names("/etc/group")
                assert got == groups, f"unexpected groups {sorted(got - groups)}, missing {sorted(groups - got)}"

        def check_operator(label):
            with subtest(f"[{label}] operator account"):
                assert field("passwd", "${user}", 2) == "1000"
                assert field("passwd", "${user}", 5) == "${settings.userdir}"
                shell = field("passwd", "${user}", 6)
                assert shell.endswith("/bin/nu"), f"login shell is {shell}"
                groups = set(machine.succeed("id -nG ${user}").split())
                assert expected_groups <= groups, f"missing groups: {expected_groups - groups}"
                assert field("group", "data", 2) == "1111"
                assert field("group", "games", 2) == "1112"
                assert field("shadow", "${user}", 1) == "${operatorHash}", "operator hash changed"
                assert machine.succeed("stat -c %U /home/${user}").strip() == "${user}"

            with subtest(f"[{label}] root stays locked"):
                root_hash = field("shadow", "root", 1)
                assert root_hash.startswith("!"), f"root hash is {root_hash!r}"
                machine.fail(f"{ssh} root@localhost true")

            with subtest(f"[{label}] operator SSH key login and passwordless sudo"):
                assert machine.succeed(f"{ssh} ${user}@localhost whoami").strip() == "${user}"
                assert machine.succeed(f"{ssh} ${user}@localhost sudo -n id -u").strip() == "0"
                machine.succeed("runuser -u ${user} -- sudo -n true")

            with subtest(f"[{label}] console password login"):
                tty[0] += 1
                n = tty[0]
                if n > 1:
                    machine.send_key(f"alt-f{n}")
                    machine.wait_until_succeeds(f"[ $(fgconsole) = {n} ]")
                machine.wait_for_unit(f"getty@tty{n}.service")
                machine.wait_until_tty_matches(f"{n}", "login: ")
                machine.send_chars("${user}\n")
                machine.wait_until_tty_matches(f"{n}", "Password: ")
                machine.send_chars("test\n")
                machine.wait_until_succeeds(f"loginctl list-sessions --no-legend | grep -E '${user} .*tty{n}'")

            check_files(label)

        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("sshd.service")
        machine.succeed(f"install -m 600 ${privateKey} {key}")
        print(f"boot: {manager()}")
        print(machine.succeed("journalctl -b -o cat | grep -E 'lockRootPassword|linkNushellConfig|userborn' || true"))

        with subtest("the root-lock snippet does not fail on a fresh boot"):
            machine.fail("journalctl -b -o cat | grep -q \"snippet 'lockRootPassword' failed\"")
            if "${mode}" == "userborn":
                machine.require_unit_state("lock-root-password.service", "active")

        check_operator("boot")
        check_population("boot", base_login, base_active, base_groups)

        base = machine.succeed("readlink -f /run/current-system").strip()

        with subtest("a root password set by hand is locked again by the next switch"):
            machine.succeed("usermod -p '${operatorHash}' root")
            assert not field("shadow", "root", 1).startswith("!")

        with subtest("switch: add a user and a group"):
            rc, out = machine.execute(f"{base}/specialisation/added/bin/switch-to-configuration switch 2>&1")
            print(f"switch exit={rc}\n{out}")
            assert rc == 0, "switch failed"
            print(f"after switch: {manager()}")
            assert field("passwd", "extra", 2) != ""
            assert field("shadow", "extra", 1) == "${operatorHash}"
            assert "extragrp" in machine.succeed("id -nG extra").split()
            assert "extragrp" in machine.succeed("id -nG ${user}").split()

        check_operator("switched")
        check_population("switched", base_login | {stray}, base_active | {stray}, base_groups | {stray_group})

        with subtest("rollback"):
            # `test`, not `switch`: the VM has no installable bootloader, and `switch` aborts on
            # grub-install before activating. Activation (and so the user database) is identical.
            rc, out = machine.execute(f"{base}/bin/switch-to-configuration test 2>&1")
            print(f"rollback exit={rc}\n{out}")
            assert rc == 0, "rollback failed"
            print(f"after rollback: {manager()}")
            print(f"{stray} after rollback:", machine.execute(f"getent passwd {stray}; getent shadow {stray}; getent group {stray_group}; id -nG ${user}; ls -ld /home/{stray}")[1])

        check_operator("rolled-back")

        # GH-206: what each manager leaves behind for the user and group the rollback dropped,
        # then the runbook's manual cleanup ("Rollback", step 3) and the state it must reach.
        if "${mode}" == "perl":
            with subtest("[rolled-back] perl deletes the dropped user and its group"):
                assert not present("passwd", stray), f"{stray} survived the rollback"
                assert not present("group", stray_group), f"{stray_group} survived the rollback"
                assert stray_group not in machine.succeed("id -nG ${user}").split()
            check_population("rolled-back", base_login, base_active, base_groups)
        else:
            if "${mode}" == "userborn":
                with subtest("[rolled-back] userborn locks the dropped user and keeps its group"):
                    assert present("passwd", stray), f"userborn deleted {stray}"
                    assert field("shadow", stray, 1) == "!*", f"{stray} hash is {field('shadow', stray, 1)!r}"
                    assert present("group", stray_group), f"userborn deleted {stray_group}"
                    assert members(stray_group) == set(), f"{stray_group} members {members(stray_group)}"
                check_population("rolled-back", base_login | {stray}, base_active, base_groups | {stray_group})
            else:
                with subtest("[rolled-back] perl leaves the user userborn created active"):
                    assert field("shadow", stray, 1) == "${operatorHash}", "the stray user's hash changed"
                    # The group is imperative to perl too, so it keeps every member, the operator
                    # included, although the base configuration no longer puts the operator in it.
                    got = members(stray_group)
                    assert got == {stray, "${user}"}, f"{stray_group} members {got}"
                check_population("rolled-back", base_login | {stray}, base_active | {stray}, base_groups | {stray_group})

            with subtest("runbook: find the users created while userborn was on, and remove them"):
                # Keep in step with docs/runbooks/userborn.md, "Rollback". Normal users get uids
                # 1000-29999; the nixbld users start at 30001, so an upper bound of 60000 lists them.
                found = set(machine.succeed("awk -F: '$3 >= 1000 && $3 < 30000 {print $1}' /etc/passwd").split())
                assert found == base_normal | {stray}, f"the runbook's awk lists {sorted(found)}"
                undeclared = found - base_normal
                for name in sorted(undeclared):
                    machine.succeed(f"userdel {name}")
                # userdel removes only the user's own primary group, so the dropped group stays
                # until it is removed too.
                assert present("group", stray_group), f"userdel removed {stray_group}"
                found = names("/etc/group") - base_groups
                assert found == {stray_group}, f"undeclared groups {sorted(found)}"
                for name in sorted(found):
                    machine.succeed(f"groupdel {name}")

            check_population("cleaned-up", base_login, base_active, base_groups)
            check_operator("cleaned-up")

            with subtest("the cleaned-up state survives the next activation"):
                rc, out = machine.execute(f"{base}/bin/switch-to-configuration test 2>&1")
                print(f"re-activation exit={rc}\n{out}")
                assert rc == 0, "re-activation failed"
            check_population("re-activated", base_login, base_active, base_groups)
      '';
    })
