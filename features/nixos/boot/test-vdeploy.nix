# NixOS VM test: the Secure Boot path of features/nixos/boot as vdeploy applies it on drakkar
# (GH-184, ADR-0007). This is the sibling of ./test.nix, which covers comin (muninn).
#
# It runs the REAL `vdeploy apply` (features/nix/vdeploy, through the `vdeploy-apply` unit
# wrapper), so the order is vdeploy's own (rust/tools/vdeploy/src/apply.vlt):
#   1. X/bin/switch-to-configuration test     X is live, the bootloader is not touched
#   2. vhealth on X's probes                   healthy, or roll back with prev's `test`
#   3. nix-env -p /nix/var/nix/profiles/system --set X
#   4. X/bin/switch-to-configuration boot      lzbt runs here, after X is already live
# It boots the real path: OVMF, then systemd-boot or lanzaboote's UKI from the ESP, then the
# kernel (virtualisation.useBootLoader), never direct kernel boot.
#
# drakkar's profile layout, read on the host 2026-11-27 (no root): vdeploy owns the `system`
# profile at a high generation (system-585), and comin's old system-profiles/ directory is
# still there, root-only (d---------), with lower generation numbers.
#
#   gen 1 / 585     the plain machine on the Python systemd-boot installer
#   KEYS MISSING    vdeploy-apply X (Secure Boot on) with no /var/lib/sbctl. Asserted:
#                   step 4 fails; vdeploy still reports "switched" and exits 0, its note
#                   says the boot entry was not written; X is running and is the system
#                   profile's newest generation; X is not marked bad; the ESP has no UKI
#                   and loader.conf is unchanged. Re-applying X once the keys exist is
#                   "already": vdeploy does NOT retry step 4. A reboot boots prev.
#   keys            `sbctl create-keys`, as the runbook does
#   apply X         from prev again: the full transaction, lzbt in step 4, X the default.
#                   The runbook removes the Python entries. REBOOT: X boots via lanzaboote.
#   rollback        vdeploy-apply prev (Secure Boot off): the Python installer takes the
#                   ESP back, the runbook removes the UKIs, REBOOT: prev via systemd-boot.
#
# After every boot and apply a non-root wheel user (alice, like tom) still runs commands and
# reaches the Nix daemon, which drakkar restricts to @wheel (features/nixos/users).
#
#   nix build .#checks.x86_64-linux.lanzaboote-vdeploy-vm
# Locally, only through the serialized wrapper (.tmp/vnla/vmtest.sh). CI does not build VM
# tests on PRs.
{
  pkgs,
  inputs,
}: let
  inherit (pkgs) busybox;
in
  pkgs.testers.runNixOSTest {
    name = "lanzaboote-vdeploy-vm";

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
            features.hardening.secureBoot.enable = true;
            vmtest.secureBootGeneration = true;
          }
        ];
      };
    in {
      imports = [./default.nix ../../nix/vdeploy/default.nix ../../nix/vhealth/default.nix];

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

        features.nix.vdeploy = {
          mode = "deploy";
          url = "/srv/nothing";
          interval = "1h";
          healthWindow = "20s";
          dotfiles.enable = false;
        };
        # drakkar's restriction (features/nixos/users); vhealth is told, as on the host.
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

        # The plain generation needs sbctl to create the keys before the option is on.
        environment.systemPackages = [pkgs.sbctl pkgs.jq];
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

      def booted():
          return machine.succeed("readlink -f /run/booted-system").strip()

      def current():
          return machine.succeed("readlink -f /run/current-system").strip()

      def profile():
          return machine.succeed(f"readlink -f {profiles}/system").strip()

      def generation_of_profile():
          return machine.succeed(f"readlink {profiles}/system").strip()

      def esp():
          listing = machine.succeed("find /boot -type f | sort")
          print(listing)
          return listing

      def loader_conf():
          conf = machine.succeed("cat /boot/loader/loader.conf")
          print(conf)
          return conf

      def loader_default():
          for line in loader_conf().splitlines():
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

      def bad_marks():
          return machine.succeed("ls /var/lib/vdeploy/bad 2>/dev/null || true").split()

      def apply(toplevel):
          # The real vdeploy apply, in its transient unit; returns (exit, last.json).
          status, out = machine.execute(f"vdeploy-apply {toplevel} 2>&1")
          print(out)
          print(machine.succeed("journalctl -u vdeploy-apply --no-pager -n 40 -o cat || true"))
          last = json.loads(machine.succeed("cat /var/lib/vdeploy/last.json"))
          print(last)
          return status, last

      def non_root_works():
          t.assertEqual(machine.succeed("su - alice -c 'id -un'").strip(), "alice")
          machine.succeed("timeout 60 su - alice -c 'nix-store --store daemon -q --hash /run/current-system'")

      def up():
          machine.wait_for_unit("multi-user.target")
          machine.wait_for_unit("web.service")

      machine.start(allow_reboot=True)
      up()

      with subtest("generation 1 boots through the Python systemd-boot installer"):
          t.assertEqual(booted(), plain)
          machine.succeed("grep -qx systemd-boot /etc/vmtest-installer")
          machine.succeed("grep -l '^version Generation 1 ' /boot/loader/entries/nixos-*.conf")
          t.assertEqual(ukis(), [])
          t.assertIn(".conf", current_entry())
          non_root_works()

      with subtest("drakkar's layout: vdeploy's system profile high, comin's old profiles root-only"):
          machine.succeed(f"ln -s {plain} {profiles}/system-584-link")
          machine.succeed(f"ln -s {plain} {profiles}/system-585-link")
          machine.succeed(f"ln -sfn system-585-link {profiles}/system")
          machine.succeed(f"mkdir -p {profiles}/system-profiles")
          machine.succeed(f"ln -s {plain} {profiles}/system-profiles/comin-12-link")
          machine.succeed(f"ln -sfn comin-12-link {profiles}/system-profiles/comin")
          machine.succeed(f"chmod 000 {profiles}/system-profiles")
          machine.fail("test -e /var/lib/sbctl")

      with subtest("KEYS MISSING: vdeploy keeps X running, says the boot entry was not written, exits 0"):
          esp_before = esp()
          conf_before = loader_conf()
          status, last = apply(secure_boot)
          # step 4 failed, and vdeploy's verdict is still "switched": kept, exit 0.
          t.assertEqual(status, 0, "vdeploy-apply exits 0 when only the boot step fails")
          t.assertEqual((last["result"], last["toplevel"], last["prev"]), ("switched", secure_boot, plain), last)
          t.assertTrue(last["note"].startswith("healthy and running, but the boot entry was not written"), last["note"])
          t.assertTrue(last["health"]["healthy"], last)
          # X is live and the system profile's newest generation (586), not marked bad.
          t.assertEqual(current(), secure_boot)
          t.assertEqual(profile(), secure_boot)
          t.assertEqual(generation_of_profile(), "system-586-link")
          t.assertEqual(bad_marks(), [])
          # The ESP is as it was: no UKI, the same loader.conf, prev still the boot default.
          t.assertEqual(ukis(), [])
          t.assertEqual(loader_conf(), conf_before)
          t.assertEqual(esp(), esp_before)
          machine.succeed("grep -q 'vdeploy_last_result{result=\"switched\"} 1' /var/lib/prometheus-node-exporter-text/vdeploy-apply.prom")
          non_root_works()

      with subtest("KEYS MISSING, then keys: re-applying the running X is 'already', step 4 is not retried"):
          machine.succeed("sbctl create-keys")
          machine.succeed("test -s /var/lib/sbctl/keys/db/db.key")
          status, last = apply(secure_boot)
          t.assertEqual(status, 0)
          t.assertEqual(last["result"], "already", last)
          t.assertEqual(ukis(), [])
          t.assertEqual(loader_conf(), conf_before)

      machine.reboot()
      up()

      with subtest("KEYS MISSING: a reboot boots the previous generation through systemd-boot"):
          t.assertEqual(booted(), plain)
          machine.succeed("grep -qx systemd-boot /etc/vmtest-installer")
          t.assertIn(".conf", current_entry())
          non_root_works()

      with subtest("apply X with the keys: the full transaction, lzbt in the boot step, X the default"):
          status, last = apply(secure_boot)
          t.assertEqual(status, 0)
          t.assertEqual((last["result"], last["toplevel"], last["prev"]), ("switched", secure_boot, plain), last)
          t.assertEqual(last["note"], "now the system profile's newest generation and the boot default")
          t.assertEqual(current(), secure_boot)
          # The missing-keys apply already made X system-586; `nix-env --set` to the path the
          # profile holds adds no generation, so X is still 586, now with its boot entry.
          t.assertEqual(generation_of_profile(), "system-586-link")
          esp()
          # Every profile's generations are installed, the root-only comin ones too.
          machine.succeed("ls /boot/EFI/Linux/nixos-generation-12-*.efi")
          machine.succeed("ls /boot/EFI/Linux/nixos-generation-585-*.efi")
          default = loader_default()
          t.assertRegex(default, r"^nixos-generation-586-.*\.efi$")
          machine.succeed(f"grep -qaF 'init={secure_boot}/init' /boot/EFI/Linux/{default}")
          print(machine.succeed("sbctl verify 2>&1"))
          machine.succeed(f"sbctl verify 2>&1 | grep -F '{default}' | grep -v 'not signed' | grep -q 'signed'")
          non_root_works()

      with subtest("runbook: remove the Python installer's leftover entries"):
          machine.succeed("rm -f /boot/loader/entries/nixos-*.conf")
          esp()

      machine.reboot()
      up()

      with subtest("the firmware boots X through lanzaboote"):
          t.assertEqual(booted(), secure_boot)
          machine.succeed("grep -qx lanzaboote /etc/vmtest-installer")
          t.assertEqual(current_entry(), default)
          non_root_works()

      with subtest("rollback: vdeploy-apply prev, the Python installer takes the ESP back"):
          status, last = apply(plain)
          t.assertEqual(status, 0)
          t.assertEqual((last["result"], last["toplevel"]), ("switched", plain), last)
          t.assertEqual(last["note"], "now the system profile's newest generation and the boot default")
          t.assertEqual(generation_of_profile(), "system-587-link")
          esp()
          machine.succeed("grep -l '^version Generation 587 ' /boot/loader/entries/nixos-*.conf")
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
          # By its toplevel, not its number: the Python installer picks the default entry by
          # toplevel, and here prev is also system-1/584/585 and comin-12.
          machine.succeed(f"grep -qF 'init={plain}/init' /boot/loader/entries/{entry}")
          non_root_works()
    '';
  }
