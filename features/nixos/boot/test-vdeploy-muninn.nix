# NixOS VM test: Secure Boot with createKeys as vdeploy applies it on MUNINN (GH-184,
# GH-343, ADR-0007). muninn moves from comin to vdeploy (#437); after that its generations go
# through the `system` profile (system-N-link, N >= 11), the same path as drakkar. This test
# is muninn's gate for #445. ./test-vdeploy.nix is drakkar's (no createKeys, the
# missing-keys case); ./test.nix is the comin path.
#
# It runs the REAL `vdeploy apply` (the `vdeploy-apply` unit wrapper), so the order is
# vdeploy's own (rust/tools/vdeploy/src/apply.vlt):
#   1. X/bin/switch-to-configuration test     X is live; sbctl-keys.service, new in X, is
#                                              started here and CREATES THE KEYS
#   2. vhealth on X's probes
#   3. nix-env -p /nix/var/nix/profiles/system --set X
#   4. X/bin/switch-to-configuration boot      the install hook: sbctl-ensure-keys (a no-op
#                                              now), then lzbt signs with those keys
# Asserted from the journal: the keys are created by sbctl-keys.service before lzbt's
# "Installing Lanzaboote". Both paths take the same lock, so they cannot race.
#
# muninn's layout, read on the host 2026-11-27 (no root): a stale `system -> system-10-link`
# and comin's leftover system-profiles/comin-10 .. comin-14. vdeploy's first apply is
# system-11, whose number collides with comin-11.
#
# The node carries muninn's hardening: the STIG test-host profile (ADR-0008), the /etc
# overlay (#438) and the Nix daemon restricted to @wheel. A non-root wheel user (alice,
# standing in for tom, who owns the backup) checks every step. Boot is the real path: OVMF,
# then systemd-boot or the UKI from the ESP, then the kernel (useBootLoader).
#
#   gen 1 / 10      the plain machine on the Python systemd-boot installer
#   apply X         Secure Boot on + createKeys, from no /var/lib/sbctl: "switched", note
#                   "now ... the boot default", X is system-11; keys 0700 root; the age
#                   backup 0400 alice, decrypts with the operator key alone; the default UKI
#                   boots X and is signed
#   rerun           vdeploy-apply X is "already"; the unit and the hook again change neither
#                   keys nor backup
#   REBOOT          X boots through lanzaboote (the runbook removes the Python entries first)
#   rollback        vdeploy-apply prev: system-12 on the Python installer, keys and backup
#                   stay; the runbook removes the UKIs; REBOOT: prev through systemd-boot
#
#   nix build .#checks.x86_64-linux.lanzaboote-vdeploy-vm-muninn
# Locally, only through the serialized wrapper (.tmp/vnla/vmtest.sh). CI does not build VM
# tests on PRs.
{
  pkgs,
  inputs,
}: let
  inherit (pkgs) busybox;
  snakeOil = import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs;
in
  pkgs.testers.runNixOSTest {
    name = "lanzaboote-vdeploy-vm-muninn";

    # features/nixos/boot imports the lanzaboote module from inputs.lanzaboote.
    node.specialArgs = {inherit inputs;};

    nodes.machine = {
      config,
      lib,
      extendModules,
      ...
    }: let
      secureBoot = extendModules {
        modules = [
          {
            features.hardening.secureBoot = {
              enable = true;
              createKeys = {
                enable = true;
                # nixpkgs' snakeoil ed25519 pair stands in for common/fleet.nix's operators.
                recipients = [snakeOil.snakeOilEd25519PublicKey];
                backupOwner = "alice";
              };
            };
            vmtest.secureBootGeneration = true;
          }
        ];
      };
    in {
      imports = [
        ./default.nix
        ../../nix/vdeploy/default.nix
        ../../nix/vhealth/default.nix
        ../../security/stig/profiles/test-host.nix
        ../etc-overlay/default.nix
      ];

      options.vmtest.secureBootGeneration = lib.mkEnableOption "the Secure Boot generation of this test";

      config = {
        virtualisation = {
          useBootLoader = true;
          useEFIBoot = true;
          memorySize = 2048;
          cores = 2;
          diskSize = 4096;
        };
        boot.loader.timeout = 0;
        system.switch.enable = true;
        # qemu-vm turns timesyncd off; the STIG profile's V-268151 turns it on. The control wins.
        services.timesyncd.enable = lib.mkForce true;

        features.nix.vdeploy = {
          mode = "deploy";
          url = "/srv/nothing";
          interval = "1h";
          healthWindow = "20s";
          dotfiles.enable = false;
        };
        # muninn's restriction (features/nixos/users); vhealth is told, as on the host.
        nix.settings.allowed-users = ["@wheel"];
        nix.settings.experimental-features = ["nix-command"];
        features.nix.vhealth = {
          restrictedNixUsers = true;
          interval = "5s";
          probes.web = {
            type = "http";
            url = "http://127.0.0.1:8080/index.html";
            bodyContains = "up";
            timeout = 2000;
          };
        };
        environment.etc."web/index.html".text = "up\n";
        systemd.services.web = {
          wantedBy = ["multi-user.target"];
          serviceConfig.ExecStart = "${busybox}/bin/httpd -f -p 127.0.0.1:8080 -h /etc/web";
        };
        services.prometheus.exporters.node.enable = true;

        # The test operator's private key, in the image (useBootLoader: no host store).
        environment.etc."vmtest-operator-key".source = snakeOil.snakeOilEd25519PrivateKey;
        environment.systemPackages = [pkgs.sbctl pkgs.age pkgs.jq];
        users.users.alice = {
          isNormalUser = true;
          uid = 1000;
          extraGroups = ["wheel"];
        };
        environment.etc."vmtest-installer".text =
          if config.features.hardening.secureBoot.enable
          then "lanzaboote\n"
          else "systemd-boot\n";
        # With useBootLoader the VM does not mount the host store: X's closure goes in the image.
        system.extraDependencies =
          lib.optional (!config.vmtest.secureBootGeneration) secureBoot.config.system.build.toplevel;
      };
    };

    testScript = {nodes, ...}: let
      plain = nodes.machine.system.build.toplevel;
      secureBoot = builtins.head nodes.machine.system.extraDependencies;
    in ''
      import json

      plain = "${plain}"
      secure_boot = "${secureBoot}"
      profiles = "/nix/var/nix/profiles"
      backup = "/var/lib/sbctl-backup/sbctl-machine.tar.age"

      def booted():
          return machine.succeed("readlink -f /run/booted-system").strip()

      def current():
          return machine.succeed("readlink -f /run/current-system").strip()

      def generation_of_profile():
          return machine.succeed(f"readlink {profiles}/system").strip()

      def esp():
          listing = machine.succeed("find /boot -type f | sort")
          print(listing)
          return listing

      def loader_default():
          conf = machine.succeed("cat /boot/loader/loader.conf")
          print(conf)
          for line in conf.splitlines():
              if line.startswith("default "):
                  return line.split(" ", 1)[1].strip()
          raise Exception("loader.conf has no default")

      def current_entry():
          status = machine.succeed("bootctl status")
          print(status)
          for line in status.splitlines():
              if "Current Entry:" in line:
                  return line.split(":", 1)[1].strip()
          raise Exception("bootctl status shows no current entry")

      def ukis():
          return machine.succeed("find /boot/EFI/Linux -name 'nixos-*.efi' 2>/dev/null | sort").split()

      def apply(toplevel):
          # The real vdeploy apply, in its transient unit; returns (exit, last.json).
          status, out = machine.execute(f"vdeploy-apply {toplevel} 2>&1")
          print(out)
          last = json.loads(machine.succeed("cat /var/lib/vdeploy/last.json"))
          print(last)
          return status, last

      def first_journal_time(pattern):
          # The earliest journal line (this boot) matching pattern, as a float timestamp.
          out = machine.succeed(f"journalctl -b -o short-unix --no-pager | grep -F -- '{pattern}' | head -n 1")
          print(out)
          t.assertNotEqual(out.strip(), "", f"no journal line for {pattern!r}")
          return float(out.split()[0])

      def keys_digest():
          return machine.succeed("cd /var/lib/sbctl && find . -type f | sort | xargs sha256sum")

      def decrypt_as_operator():
          machine.succeed("install -m 0400 -o alice /etc/vmtest-operator-key /home/alice/id_ed25519")
          listing = machine.succeed(f"su - alice -c 'age -d -i ~/id_ed25519 {backup} | tar -tf -'")
          t.assertIn("sbctl/keys/db/db.key", listing)
          machine.succeed(f"su - alice -c 'age -d -i ~/id_ed25519 {backup}' | tar -xOf - sbctl/keys/db/db.key | cmp - /var/lib/sbctl/keys/db/db.key")

      def non_root_works():
          t.assertEqual(machine.succeed("su - alice -c 'id -un'").strip(), "alice")
          machine.succeed("timeout 60 su - alice -c 'nix-store --store daemon -q --hash /run/current-system'")

      def up():
          machine.wait_for_unit("multi-user.target")
          machine.wait_for_unit("web.service")

      machine.start(allow_reboot=True)
      up()

      with subtest("generation 1 boots through the Python systemd-boot installer, /etc on the overlay"):
          t.assertEqual(booted(), plain)
          machine.succeed("grep -qx systemd-boot /etc/vmtest-installer")
          t.assertEqual(machine.succeed("findmnt -n -o FSTYPE /etc").strip(), "overlay")
          t.assertEqual(ukis(), [])
          t.assertIn(".conf", current_entry())
          non_root_works()

      with subtest("muninn's layout: a stale system-10, comin's leftover comin-10 .. comin-14"):
          machine.succeed(f"ln -s {plain} {profiles}/system-10-link")
          machine.succeed(f"ln -sfn system-10-link {profiles}/system")
          machine.succeed(f"mkdir -p {profiles}/system-profiles")
          for n in range(10, 15):
              machine.succeed(f"ln -s {plain} {profiles}/system-profiles/comin-{n}-link")
          machine.succeed(f"ln -sfn comin-14-link {profiles}/system-profiles/comin")
          machine.fail("test -e /var/lib/sbctl")

      with subtest("apply X: vdeploy's order, the keys are made in `test`, before lzbt signs in `boot`"):
          status, last = apply(secure_boot)
          t.assertEqual(status, 0)
          t.assertEqual((last["result"], last["toplevel"], last["prev"]), ("switched", secure_boot, plain), last)
          t.assertEqual(last["note"], "now the system profile's newest generation and the boot default")
          t.assertEqual(current(), secure_boot)
          t.assertEqual(generation_of_profile(), "system-11-link")
          # Who made the keys, and when: sbctl-keys.service, started by the `test` step,
          # before lzbt ran in the `boot` step.
          made = machine.succeed("journalctl -b -u sbctl-keys.service -o cat --no-pager")
          print(made)
          t.assertIn("sbctl-ensure-keys: created the Secure Boot keys in /var/lib/sbctl", made)
          t.assertLess(first_journal_time("sbctl-ensure-keys: created the Secure Boot keys"), first_journal_time("Installing Lanzaboote"))
          # The keys: root-only.
          t.assertEqual(machine.succeed("stat -c '%a %U' /var/lib/sbctl").strip(), "700 root")
          machine.succeed("test -s /var/lib/sbctl/keys/db/db.key && test -s /var/lib/sbctl/GUID")
          machine.fail("su - alice -c 'cat /var/lib/sbctl/keys/db/db.key'")
          # The backup: the operator's, and it decrypts with the operator's key alone.
          t.assertEqual(machine.succeed(f"stat -c '%a %U' {backup}").strip(), "400 alice")
          decrypt_as_operator()
          # The ESP: every profile's generations, X (system-11) the default, signed.
          esp()
          for n in [1, 10, 12, 13, 14]:
              machine.succeed(f"ls /boot/EFI/Linux/nixos-generation-{n}-*.efi")
          default = loader_default()
          t.assertRegex(default, r"^nixos-generation-11-.*\.efi$")
          machine.succeed(f"grep -qaF 'init={secure_boot}/init' /boot/EFI/Linux/{default}")
          print(machine.succeed("sbctl verify 2>&1"))
          machine.succeed(f"sbctl verify 2>&1 | grep -F '{default}' | grep -v 'not signed' | grep -q 'signed'")
          non_root_works()

      with subtest("rerun: vdeploy is 'already'; the unit and the hook again change neither keys nor backup"):
          keys_before = keys_digest()
          backup_before = machine.succeed(f"sha256sum {backup}")
          status, last = apply(secure_boot)
          t.assertEqual((status, last["result"]), (0, "already"), last)
          machine.succeed("systemctl restart sbctl-keys.service")
          print(machine.succeed(f"{profiles}/system/bin/switch-to-configuration boot 2>&1"))
          t.assertEqual(keys_digest(), keys_before)
          t.assertEqual(machine.succeed(f"sha256sum {backup}"), backup_before)
          t.assertEqual(loader_default(), default)

      with subtest("runbook: remove the Python installer's leftover entries"):
          machine.succeed("rm -f /boot/loader/entries/nixos-*.conf")
          esp()

      machine.reboot()
      up()

      with subtest("the firmware boots X through lanzaboote; keys and backup unchanged"):
          t.assertEqual(booted(), secure_boot)
          machine.succeed("grep -qx lanzaboote /etc/vmtest-installer")
          t.assertEqual(current_entry(), default)
          machine.wait_for_unit("sbctl-keys.service")
          t.assertEqual(keys_digest(), keys_before)
          t.assertEqual(machine.succeed(f"sha256sum {backup}"), backup_before)
          non_root_works()

      with subtest("rollback: vdeploy-apply prev, the Python installer takes the ESP back"):
          status, last = apply(plain)
          t.assertEqual(status, 0)
          t.assertEqual((last["result"], last["toplevel"]), ("switched", plain), last)
          t.assertEqual(last["note"], "now the system profile's newest generation and the boot default")
          t.assertEqual(generation_of_profile(), "system-12-link")
          esp()
          machine.succeed("grep -l '^version Generation 12 ' /boot/loader/entries/nixos-*.conf")
          machine.succeed("test -s /var/lib/sbctl/keys/db/db.key")
          machine.succeed(f"test -s {backup}")
          non_root_works()

      with subtest("runbook: remove lanzaboote's UKIs, which the Python installer does not collect"):
          machine.succeed("rm -f /boot/EFI/Linux/nixos-generation-*.efi")
          t.assertEqual(ukis(), [])

      machine.reboot()
      up()

      with subtest("prev boots through systemd-boot again"):
          t.assertEqual(booted(), plain)
          machine.succeed("grep -qx systemd-boot /etc/vmtest-installer")
          entry = current_entry()
          t.assertIn(".conf", entry)
          # By toplevel: the Python installer picks the default entry by toplevel, and prev
          # is also system-1, system-10 and comin-10 .. 14.
          machine.succeed(f"grep -qF 'init={plain}/init' /boot/loader/entries/{entry}")
          non_root_works()
    '';
  }
