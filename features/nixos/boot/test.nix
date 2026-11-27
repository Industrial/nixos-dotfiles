# NixOS VM test for the Secure Boot path of features/nixos/boot (GH-184, ADR-0007), as
# COMIN deploys it on MUNINN. It walks the migration end to end through the real boot path:
# OVMF firmware, then systemd-boot, then the kernel, with no direct kernel boot
# (virtualisation.useBootLoader). drakkar is deployed by vdeploy instead; that order, and
# the boot step failing for missing keys, is ./test-vdeploy.nix (lanzaboote-vdeploy-vm).
#
# comin on main runs `operation = "switch"` (features/fleet/comin.nix): set
# system-profiles/comin, then a LIVE `switch-to-configuration switch`, which activates and
# installs the bootloader in one step. switch-to-configuration installs the bootloader
# first, so a failing lzbt fails comin's switch before the new generation is activated.
#
# muninn's profile layout, read on the host 2026-11-27 (no root): a stale `system` profile
# (system -> system-10-link, from the install, 2026-11-01) and comin's generations
# system-profiles/comin-10 .. comin-14. The generation NUMBERS collide across the two
# profiles (system-10 and comin-10); lzbt's UKI names and the default hook must cope.
#
#   generation 1    systemd-boot with the Python installer, which is what every host runs today
#   muninn layout   system-10-link (stale), comin-10 .. comin-14, all the plain machine
#   KEYS MISSING    `manual` (Secure Boot on, createKeys off) comin's way with no
#                   /var/lib/sbctl. Asserted: `switch` fails in its bootloader step, BEFORE
#                   activating (switch-to-configuration-ng installs the bootloader first),
#                   so the host stays on prev, the ESP is untouched, and only comin's
#                   profile already names it (comin-15)
#   comin-16        muninn's configuration: Secure Boot on AND createKeys, comin's way. The
#                   install hook creates the keys (root, 0700) before lzbt signs, so the
#                   first switch succeeds. sbctl-keys.service writes the age backup, owned
#                   by the operator, which decrypts with the operator's ssh key alone. A
#                   rerun (unit and hook) changes neither keys nor backup; a removed backup
#                   comes back from the same keys; a keys/ without db.key is refused, not
#                   overwritten. lzbt installs signed UKIs for every profile, comin-16 the
#                   default. The runbook removes the Python installer's leftover entries.
#                   REBOOT: the firmware boots comin-16 through lanzaboote.
#   system-11       a by-hand nixos-rebuild into the stale `system` profile, whose number
#                   collides with comin-11: both get a UKI, the default still boots X
#   comin-17        the rollback: Secure Boot off again, comin's way, live switch OUT. The
#                   Python installer takes the ESP back (keys and backup stay), the
#                   runbook's cleanup removes lanzaboote's UKIs, and after a REBOOT comin-17
#                   boots through systemd-boot.
#
# The node carries muninn's real hardening: the STIG test-host profile (ADR-0008) and the
# Nix daemon restricted to @wheel. After each live switch and boot, a non-root wheel user
# still runs commands and reaches the daemon. Secure Boot stays off in the VM firmware
# (stock OVMF): that is how the host runs between the first deploy and key enrollment, and
# enrollment needs someone at the machine.
#
#   nix build .#checks.x86_64-linux.lanzaboote-vm
# Locally, only through the serialized wrapper (.tmp/vnla/vmtest.sh). CI does not build VM
# tests on PRs.
{
  pkgs,
  inputs,
}: let
  snakeOil = import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs;
in
  pkgs.testers.runNixOSTest {
    name = "lanzaboote-vm";

    # features/nixos/boot imports the lanzaboote module from inputs.lanzaboote.
    node.specialArgs = {inherit inputs;};

    nodes.machine = {
      config,
      lib,
      extendModules,
      ...
    }: let
      # The Secure Boot generations: the same machine with the option on. `manual` expects
      # the operator to have created the keys (the missing-keys case); `create` is muninn's
      # configuration, createKeys on, its backup encrypted to a test operator key (nixpkgs'
      # snakeoil ed25519 pair, standing in for common/fleet.nix's operator keys).
      secureBoot = createKeys:
        extendModules {
          modules = [
            {
              features.hardening.secureBoot = {
                enable = true;
                createKeys = lib.mkIf createKeys {
                  enable = true;
                  recipients = [snakeOil.snakeOilEd25519PublicKey];
                  backupOwner = "alice";
                };
              };
              vmtest.secureBootGeneration = true;
            }
          ];
        };
    in {
      imports = [./default.nix ../../security/stig/profiles/test-host.nix];

      options.vmtest.secureBootGeneration = lib.mkEnableOption "the Secure Boot generation of this test";

      config = {
        virtualisation = {
          useBootLoader = true;
          useEFIBoot = true;
          memorySize = 2048;
          cores = 2;
        };
        boot.loader.timeout = 0;
        # qemu-vm turns timesyncd off; the STIG profile's V-268151 turns it on. The control wins.
        services.timesyncd.enable = lib.mkForce true;
        # muninn's restriction (features/nixos/users), so alice must reach the daemon as wheel.
        nix.settings.allowed-users = ["@wheel"];
        # The test operator's private key, in the image (useBootLoader: no host store).
        environment.etc."vmtest-operator-key".source = snakeOil.snakeOilEd25519PrivateKey;
        # sbctl for the checks, age for decrypting the backup with the test operator key.
        environment.systemPackages = [pkgs.sbctl pkgs.age];
        users.users.alice = {
          isNormalUser = true;
          extraGroups = ["wheel"];
        };
        environment.etc."vmtest-installer".text =
          if config.features.hardening.secureBoot.enable
          then "lanzaboote\n"
          else "systemd-boot\n";
        # The Secure Boot generations' closures have to be in the image: with useBootLoader
        # the VM does not mount the host store. [manual, create], in that order.
        system.extraDependencies = lib.optionals (!config.vmtest.secureBootGeneration) [
          (secureBoot false).config.system.build.toplevel
          (secureBoot true).config.system.build.toplevel
        ];
      };
    };

    testScript = {nodes, ...}: let
      plain = nodes.machine.system.build.toplevel;
      deps = nodes.machine.system.extraDependencies;
    in ''
      plain = "${plain}"
      manual = "${builtins.elemAt deps 0}"
      secure_boot = "${builtins.elemAt deps 1}"
      operator_key = "/etc/vmtest-operator-key"
      backup = "/var/lib/sbctl-backup/sbctl-machine.tar.age"
      profiles = "/nix/var/nix/profiles"
      comin = f"{profiles}/system-profiles/comin"

      def booted():
          return machine.succeed("readlink -f /run/booted-system").strip()

      def esp():
          listing = machine.succeed("find /boot -type f | sort")
          print(listing)
          return listing

      def current_entry():
          status = machine.succeed("bootctl status")
          print(status)
          for line in status.splitlines():
              if "Current Entry:" in line:
                  return line.split(":", 1)[1].strip()
          raise Exception("bootctl status shows no current entry")

      def loader_default():
          conf = machine.succeed("cat /boot/loader/loader.conf")
          print(conf)
          for line in conf.splitlines():
              if line.startswith("default "):
                  return line.split(" ", 1)[1].strip()
          raise Exception("loader.conf has no default")

      # The Python installer names its entries nixos-<sha256 of the contents>.conf; the
      # generation is in the `version Generation <N> ...` line.
      def python_entry(generation):
          machine.succeed(f"grep -l '^version Generation {generation} ' /boot/loader/entries/nixos-*.conf")

      def deploy(profile, system, action):
          # What comin (system-profiles/comin, `switch`) and a by-hand nixos-rebuild (system)
          # both do: set the profile, then run the new system's switch-to-configuration.
          machine.succeed(f"mkdir -p {profiles}/system-profiles")
          machine.succeed(f"nix-env -p {profile} --set {system}")
          print(machine.succeed(f"{system}/bin/switch-to-configuration {action} 2>&1"))

      def non_root_works():
          t.assertEqual(machine.succeed("su - alice -c 'id -un'").strip(), "alice")
          machine.succeed("timeout 60 su - alice -c 'nix-store --store daemon -q --hash /run/current-system'")

      def uki_for(generation, system):
          # The UKI of <generation> that boots <system>; with colliding numbers there may be
          # several nixos-generation-<generation>-*.efi.
          names = machine.succeed(f"ls /boot/EFI/Linux/ | grep -E '^nixos-generation-{generation}-.*[.]efi$'").split()
          hits = [n for n in names if machine.execute(f"grep -qaF 'init={system}/init' /boot/EFI/Linux/{n}")[0] == 0]
          t.assertGreaterEqual(len(hits), 1, f"generation {generation}: {names}, none boots {system}")
          return sorted(hits)[-1]

      machine.start(allow_reboot=True)
      machine.wait_for_unit("multi-user.target")

      with subtest("generation 1 boots through the Python systemd-boot installer"):
          t.assertEqual(booted(), plain)
          machine.succeed("grep -qx systemd-boot /etc/vmtest-installer")
          python_entry(1)
          machine.fail("ls /boot/EFI/Linux/nixos-*.efi")
          t.assertIn(".conf", current_entry())

      with subtest("muninn's layout: a stale system-10, comin-10 .. comin-14, colliding numbers"):
          machine.succeed(f"ln -s {plain} {profiles}/system-10-link")
          machine.succeed(f"ln -sfn system-10-link {profiles}/system")
          machine.succeed(f"mkdir -p {profiles}/system-profiles")
          for n in range(10, 15):
              machine.succeed(f"ln -s {plain} {profiles}/system-profiles/comin-{n}-link")
          machine.succeed(f"ln -sfn comin-14-link {comin}")
          machine.fail("test -e /var/lib/sbctl")

      with subtest("KEYS MISSING, comin's way: the switch fails before activating, the host stays on prev"):
          esp_before = esp()
          conf_before = machine.succeed("cat /boot/loader/loader.conf")
          # comin sets its profile first, then runs `switch`; switch-to-configuration installs
          # the bootloader BEFORE it activates, and exits 1 when that fails.
          machine.succeed(f"nix-env -p {comin} --set {manual}")
          status, out = machine.execute(f"{manual}/bin/switch-to-configuration switch 2>&1")
          print(out)
          t.assertNotEqual(status, 0, "comin's switch fails when the keys are missing")
          t.assertIn("Failed to read public key", out)
          t.assertIn("Failed to install bootloader", out)
          # Not activated: the host runs prev. comin's profile already names X (comin-15).
          machine.succeed(f"test $(readlink -f /run/current-system) = {plain}")
          machine.succeed("grep -qx systemd-boot /etc/vmtest-installer")
          t.assertEqual(machine.succeed(f"readlink {comin}").strip(), "comin-15-link")
          # The ESP is untouched, so a reboot boots prev through systemd-boot.
          t.assertEqual(esp(), esp_before)
          t.assertEqual(machine.succeed("cat /boot/loader/loader.conf"), conf_before)
          non_root_works()

      with subtest("comin-16 with createKeys: the hook creates the keys before lzbt signs, the switch succeeds"):
          machine.fail("test -e /var/lib/sbctl")
          deploy(comin, secure_boot, "switch")
          esp()
          t.assertEqual(machine.succeed(f"readlink {comin}").strip(), "comin-16-link")
          machine.succeed(f"test $(readlink -f /run/current-system) = {secure_boot}")
          # The keys: root-only, in pkiBundle.
          t.assertEqual(machine.succeed("stat -c '%a %U' /var/lib/sbctl").strip(), "700 root")
          machine.succeed("test -s /var/lib/sbctl/keys/db/db.key")
          machine.succeed("test -s /var/lib/sbctl/keys/db/db.pem")
          machine.succeed("test -s /var/lib/sbctl/GUID")
          machine.fail("su - alice -c 'cat /var/lib/sbctl/keys/db/db.key'")
          # Every profile's generations: system-1, the stale system-10, comin-10 .. comin-16.
          for n in [1, 10, 11, 12, 13, 14]:
              uki_for(n, plain)
          default = loader_default()
          t.assertEqual(default, uki_for(16, secure_boot))
          print(machine.succeed("sbctl verify 2>&1"))
          machine.succeed(f"sbctl verify 2>&1 | grep -F '{default}' | grep -v 'not signed' | grep -q 'signed'")
          non_root_works()

      def keys_digest():
          return machine.succeed("cd /var/lib/sbctl && find . -type f | sort | xargs sha256sum")

      def decrypt_as_operator():
          # The operator (alice here, tom on muninn) reads the backup and decrypts it with
          # their ssh key alone; the decrypted db.key is the one on disk.
          machine.succeed(f"install -m 0400 -o alice {operator_key} /home/alice/id_ed25519")
          listing = machine.succeed(f"su - alice -c 'age -d -i ~/id_ed25519 {backup} | tar -tf -'")
          print(listing)
          t.assertIn("sbctl/keys/db/db.key", listing)
          machine.succeed(f"su - alice -c 'age -d -i ~/id_ed25519 {backup}' | tar -xOf - sbctl/keys/db/db.key | cmp - /var/lib/sbctl/keys/db/db.key")

      with subtest("createKeys: the backup is written, owned by the operator, and decrypts with the operator key"):
          machine.wait_for_unit("sbctl-keys.service")
          t.assertEqual(machine.succeed(f"stat -c '%a %U' {backup}").strip(), "400 alice")
          decrypt_as_operator()

      with subtest("createKeys: a rerun is a no-op, and existing keys are never overwritten"):
          keys_before = keys_digest()
          backup_before = machine.succeed(f"sha256sum {backup}")
          machine.succeed("systemctl restart sbctl-keys.service")
          # The install hook again, which runs sbctl-ensure-keys before lzbt.
          print(machine.succeed(f"{secure_boot}/bin/switch-to-configuration boot 2>&1"))
          t.assertEqual(keys_digest(), keys_before)
          t.assertEqual(machine.succeed(f"sha256sum {backup}"), backup_before)
          # A backup removed by hand comes back, from the same keys.
          machine.succeed(f"rm {backup}")
          machine.succeed("systemctl restart sbctl-keys.service")
          t.assertEqual(keys_digest(), keys_before)
          decrypt_as_operator()
          # A keys/ without db.key is refused, not overwritten.
          machine.succeed("mv /var/lib/sbctl /var/lib/sbctl.real && install -d -m 0700 /var/lib/sbctl/keys")
          status, _ = machine.execute("systemctl restart sbctl-keys.service")
          t.assertNotEqual(status, 0, "sbctl-keys.service fails on a partial bundle")
          ensure = "$(systemctl cat sbctl-keys.service | sed -n 's|^ExecStart=\\(.*/sbctl-ensure-keys\\)$|\\1|p')"
          status, out = machine.execute(f"{ensure} 2>&1")
          print(out)
          t.assertNotEqual(status, 0)
          t.assertIn("refusing to create keys over it", out)
          machine.fail("test -e /var/lib/sbctl/keys/db")
          machine.succeed("rm -r /var/lib/sbctl && mv /var/lib/sbctl.real /var/lib/sbctl")
          machine.succeed("systemctl restart sbctl-keys.service")
          t.assertEqual(keys_digest(), keys_before)
          # The refusal step left the boot default as it was.
          default = loader_default()
          t.assertEqual(default, uki_for(16, secure_boot))

      with subtest("runbook: remove the Python installer's leftover entries"):
          machine.succeed("rm -f /boot/loader/entries/nixos-*.conf")
          esp()

      machine.reboot()
      machine.wait_for_unit("multi-user.target")

      with subtest("the firmware boots comin-16 through lanzaboote"):
          t.assertEqual(booted(), secure_boot)
          machine.succeed("grep -qx lanzaboote /etc/vmtest-installer")
          t.assertEqual(current_entry(), default)
          non_root_works()

      with subtest("system-11, colliding with comin-11: both get a UKI, the default still boots X"):
          deploy(f"{profiles}/system", secure_boot, "boot")
          t.assertEqual(machine.succeed(f"readlink {profiles}/system").strip(), "system-11-link")
          # system-11 and comin-11 share a number; each gets its own UKI.
          uki_for(11, secure_boot)
          uki_for(11, plain)
          # system-11 is the same toplevel as comin-16, so the hook keeps the highest UKI that
          # boots it: the default still boots secure_boot.
          default = loader_default()
          machine.succeed(f"grep -qaF 'init={secure_boot}/init' /boot/EFI/Linux/{default}")

      with subtest("comin-17: rollback, live switch out of lanzaboote, the Python installer takes the ESP back"):
          deploy(comin, plain, "switch")
          esp()
          t.assertEqual(machine.succeed(f"readlink {comin}").strip(), "comin-17-link")
          machine.succeed(f"test $(readlink -f /run/current-system) = {plain}")
          python_entry(17)
          # The keys and the backup stay; rolling back removes neither.
          machine.succeed("test -s /var/lib/sbctl/keys/db/db.key")
          machine.succeed(f"test -s {backup}")
          non_root_works()

      with subtest("runbook: remove lanzaboote's UKIs, which the Python installer does not collect"):
          machine.succeed("rm -f /boot/EFI/Linux/nixos-generation-*.efi")
          machine.fail("ls /boot/EFI/Linux/nixos-*.efi")
          esp()

      machine.reboot()
      machine.wait_for_unit("multi-user.target")

      with subtest("comin-16 boots through systemd-boot again"):
          t.assertEqual(booted(), plain)
          machine.succeed("grep -qx systemd-boot /etc/vmtest-installer")
          entry = current_entry()
          t.assertIn(".conf", entry)
          # By its toplevel, not its number: the Python installer picks the default entry by
          # toplevel, and the plain machine is also system-1, system-10 and comin-10 .. 14.
          machine.succeed(f"grep -qF 'init={plain}/init' /boot/loader/entries/{entry}")
          non_root_works()
    '';
  }
