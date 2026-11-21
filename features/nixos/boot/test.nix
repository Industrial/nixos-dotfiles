# NixOS VM test for the Secure Boot path of features/nixos/boot (GH-184, ADR-0007). It
# walks the drakkar migration end to end through the real boot path: OVMF firmware, then
# systemd-boot, then the kernel, with no direct kernel boot (virtualisation.useBootLoader).
# It uses drakkar's profile layout: comin deploys through system-profiles/comin, and the
# `system` profile holds a STALE generation with a higher number (drakkar's system-493).
#
#   generation 1    systemd-boot with the Python installer, which is what every host runs today
#   stale system    system-900-link -> generation 1, the highest version on the machine
#   keys            `sbctl create-keys` into pkiBundle, as the runbook does
#   comin-1         features.hardening.secureBoot.enable, deployed comin's way
#                   (system-profiles/comin, then a LIVE `switch-to-configuration switch`).
#                   lzbt installs signed UKIs for every profile, and the boot default is
#                   comin-1, not the stale system-900. The runbook removes the Python
#                   installer's leftover entries. REBOOT: the firmware boots comin-1
#                   through lanzaboote.
#   system-901      a deploy-rs/nixos-rebuild-style generation (the `system` profile)
#                   becomes the default the same way
#   comin-2         the rollback: Secure Boot off again, comin's way, live switch OUT. The
#                   Python installer takes the ESP back, the runbook's cleanup removes
#                   lanzaboote's UKIs, and after a REBOOT comin-2 boots through systemd-boot.
#
# After each live switch, a non-root user still runs commands (brief rule 17). Secure Boot
# stays off in the VM firmware (stock OVMF). That is how drakkar runs between the first
# deploy and key enrollment, and enrollment needs someone at the machine.
#
#   nix build .#checks.x86_64-linux.lanzaboote-vm
# Locally, only through the serialized wrapper (.tmp/vnla/vmtest.sh). CI does not build VM
# tests on PRs.
{
  pkgs,
  inputs,
}:
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
    # The Secure Boot generation: the same machine with the option on.
    secureBoot = extendModules {
      modules = [
        {
          features.hardening.secureBoot.enable = true;
          vmtest.secureBootGeneration = true;
        }
      ];
    };
  in {
    imports = [./default.nix];

    options.vmtest.secureBootGeneration = lib.mkEnableOption "the Secure Boot generation of this test";

    config = {
      virtualisation = {
        useBootLoader = true;
        useEFIBoot = true;
        memorySize = 2048;
        cores = 2;
      };
      boot.loader.timeout = 0;
      # The plain generation needs sbctl to create the keys before the option is on.
      environment.systemPackages = [pkgs.sbctl];
      users.users.alice.isNormalUser = true;
      environment.etc."vmtest-installer".text =
        if config.features.hardening.secureBoot.enable
        then "lanzaboote\n"
        else "systemd-boot\n";
      # The Secure Boot generation's closure has to be in the image: with useBootLoader
      # the VM does not mount the host store.
      system.extraDependencies =
        lib.optional (!config.vmtest.secureBootGeneration) secureBoot.config.system.build.toplevel;
    };
  };

  testScript = {nodes, ...}: let
    plain = nodes.machine.system.build.toplevel;
    secureBoot = builtins.head nodes.machine.system.extraDependencies;
  in ''
    plain = "${plain}"
    secure_boot = "${secureBoot}"
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
        # What comin (system-profiles/comin) and deploy-rs (system) both do: set the
        # profile, then run the new system's switch-to-configuration.
        machine.succeed(f"mkdir -p {profiles}/system-profiles")
        machine.succeed(f"nix-env -p {profile} --set {system}")
        print(machine.succeed(f"{system}/bin/switch-to-configuration {action} 2>&1"))

    def non_root_works():
        t.assertEqual(machine.succeed("su - alice -c 'id -un'").strip(), "alice")
        machine.succeed("su - alice -c 'nix-store --version'")

    machine.start(allow_reboot=True)
    machine.wait_for_unit("multi-user.target")

    with subtest("generation 1 boots through the Python systemd-boot installer"):
        t.assertEqual(booted(), plain)
        machine.succeed("grep -qx systemd-boot /etc/vmtest-installer")
        python_entry(1)
        machine.fail("ls /boot/EFI/Linux/nixos-*.efi")
        t.assertIn(".conf", current_entry())

    with subtest("drakkar's layout: a stale, higher-numbered system profile"):
        machine.succeed(f"ln -s {plain} {profiles}/system-900-link")
        machine.succeed(f"ln -sfn system-900-link {profiles}/system")

    with subtest("keys: sbctl create-keys into pkiBundle"):
        machine.succeed("sbctl create-keys")
        machine.succeed("test -s /var/lib/sbctl/keys/db/db.pem")
        machine.succeed("test -s /var/lib/sbctl/keys/db/db.key")

    with subtest("comin-1: live switch into lanzaboote, every profile installed, comin-1 the default"):
        deploy(comin, secure_boot, "switch")
        esp()
        machine.succeed(f"test $(readlink -f /run/current-system) = {secure_boot}")
        # Every profile's generations: comin-1, system-1 and the stale system-900.
        machine.succeed("ls /boot/EFI/Linux/nixos-generation-900-*.efi")
        t.assertEqual(len(machine.succeed("ls /boot/EFI/Linux/nixos-generation-1-*.efi").split()), 2)
        default = loader_default()
        t.assertRegex(default, r"^nixos-generation-1-.*\.efi$")
        machine.succeed(f"grep -qaF 'init={secure_boot}/init' /boot/EFI/Linux/{default}")
        print(machine.succeed("sbctl verify 2>&1"))
        machine.succeed(f"sbctl verify 2>&1 | grep -F '{default}' | grep -v 'not signed' | grep -q 'signed'")
        non_root_works()

    with subtest("runbook: remove the Python installer's leftover entries"):
        machine.succeed("rm -f /boot/loader/entries/nixos-*.conf")
        esp()

    machine.reboot()
    machine.wait_for_unit("multi-user.target")

    with subtest("the firmware boots comin-1 through lanzaboote, not the stale system-900"):
        t.assertEqual(booted(), secure_boot)
        machine.succeed("grep -qx lanzaboote /etc/vmtest-installer")
        t.assertEqual(current_entry(), default)
        non_root_works()

    with subtest("system-901 (deploy-rs/nixos-rebuild style) becomes the default the same way"):
        deploy(f"{profiles}/system", secure_boot, "boot")
        t.assertRegex(loader_default(), r"^nixos-generation-901-.*\.efi$")

    with subtest("comin-2: rollback, live switch out of lanzaboote, the Python installer takes the ESP back"):
        deploy(comin, plain, "switch")
        esp()
        machine.succeed(f"test $(readlink -f /run/current-system) = {plain}")
        python_entry(2)
        non_root_works()

    with subtest("runbook: remove lanzaboote's UKIs, which the Python installer does not collect"):
        machine.succeed("rm -f /boot/EFI/Linux/nixos-generation-*.efi")
        machine.fail("ls /boot/EFI/Linux/nixos-*.efi")
        esp()

    machine.reboot()
    machine.wait_for_unit("multi-user.target")

    with subtest("comin-2 boots through systemd-boot again"):
        t.assertEqual(booted(), plain)
        machine.succeed("grep -qx systemd-boot /etc/vmtest-installer")
        entry = current_entry()
        t.assertIn(".conf", entry)
        machine.succeed(f"grep -q '^version Generation 2 ' /boot/loader/entries/{entry}")
        non_root_works()
  '';
}
