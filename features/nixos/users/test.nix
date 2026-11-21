# NixOS VM test for the user database on a drakkar-like host (GH-187): the operator's
# account, the locked root, operator SSH, passwordless sudo and console login, across a
# switch that adds a user and a group and a rollback.
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
in
  assert lib.elem mode ["perl" "userborn" "migrate"];
    pkgs.testers.runNixOSTest {
      name = "users-vm-${mode}";
      globalTimeout = 1200;

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
            groups.extragrp = {};
            users.extra = {
              isNormalUser = true;
              extraGroups = ["extragrp"];
              hashedPassword = operatorHash;
            };
            users.${user}.extraGroups = ["extragrp"];
          };
        };

        virtualisation = {
          cores = 2;
          memorySize = 1536;
        };
      };

      testScript = ''
        expected_groups = set(${builtins.toJSON expectedGroups})
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

        with subtest("rollback"):
            # `test`, not `switch`: the VM has no installable bootloader, and `switch` aborts on
            # grub-install before activating. Activation (and so the user database) is identical.
            rc, out = machine.execute(f"{base}/bin/switch-to-configuration test 2>&1")
            print(f"rollback exit={rc}\n{out}")
            assert rc == 0, "rollback failed"
            print(f"after rollback: {manager()}")
            # Recorded, not asserted: the two managers treat an undeclared user differently.
            print("extra after rollback:", machine.execute("getent passwd extra; getent shadow extra; getent group extragrp; id -nG ${user}")[1])

        check_operator("rolled-back")
      '';
    }
