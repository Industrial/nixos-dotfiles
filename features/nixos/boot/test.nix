# NixOS VM test for the Secure Boot path of features/nixos/boot (GH-184, ADR-0007). It
# walks the drakkar migration end to end through the real boot path: OVMF firmware, then
# systemd-boot, then the kernel, with no direct kernel boot (virtualisation.useBootLoader).
#
#   generation 1  systemd-boot with the Python installer, which is what every host runs today
#   keys          `sbctl create-keys` into pkiBundle, as the runbook does
#   generation 2  features.hardening.secureBoot.enable: lzbt installs signed UKIs, the
#                 runbook removes the Python installer's leftover entries, and after a
#                 REBOOT the firmware boots generation 2 through lanzaboote
#   generation 3  the rollback: Secure Boot off again (what reverting the enable deploys).
#                 The Python installer takes the ESP back, the runbook's cleanup removes
#                 lanzaboote's UKIs, and after a REBOOT generation 3 boots through systemd-boot
#
# Secure Boot stays off in the VM firmware (stock OVMF). That is how drakkar runs between
# the first deploy and key enrollment, and enrollment needs someone at the machine.
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
    # Generation 2: the same machine with the option on.
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
      # Generation 1 needs sbctl to create the keys before the option is on.
      environment.systemPackages = [pkgs.sbctl];
      environment.etc."vmtest-installer".text =
        if config.features.hardening.secureBoot.enable
        then "lanzaboote\n"
        else "systemd-boot\n";
      # Generation 2's closure has to be in the image: with useBootLoader the VM does not
      # mount the host store.
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
    profile = "/nix/var/nix/profiles/system"

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

    # The Python installer names its entries nixos-<sha256 of the contents>.conf; the
    # generation is in the `version Generation <N> ...` line.
    def python_entry(generation):
        machine.succeed(f"grep -l '^version Generation {generation} ' /boot/loader/entries/nixos-*.conf")

    def switch_to(system):
        machine.succeed(f"nix-env -p {profile} --set {system}")
        print(machine.succeed(f"{profile}/bin/switch-to-configuration boot 2>&1"))

    machine.start(allow_reboot=True)
    machine.wait_for_unit("multi-user.target")

    with subtest("generation 1 boots through the Python systemd-boot installer"):
        t.assertEqual(booted(), plain)
        machine.succeed("grep -qx systemd-boot /etc/vmtest-installer")
        python_entry(1)
        machine.fail("ls /boot/EFI/Linux/nixos-*.efi")
        t.assertIn(".conf", current_entry())

    with subtest("keys: sbctl create-keys into pkiBundle"):
        machine.succeed("sbctl create-keys")
        machine.succeed("test -s /var/lib/sbctl/keys/db/db.pem")
        machine.succeed("test -s /var/lib/sbctl/keys/db/db.key")

    with subtest("generation 2: lzbt installs signed UKIs"):
        switch_to(secure_boot)
        esp()
        machine.succeed("ls /boot/EFI/Linux/nixos-generation-2-*.efi")
        verify = machine.succeed("sbctl verify 2>&1")
        print(verify)
        machine.succeed("sbctl verify 2>&1 | grep nixos-generation-2- | grep -v 'not signed' | grep -q 'signed'")

    with subtest("runbook: remove the Python installer's leftover entries"):
        machine.succeed("rm -f /boot/loader/entries/nixos-*.conf")
        esp()

    machine.reboot()
    machine.wait_for_unit("multi-user.target")

    with subtest("the firmware boots generation 2 through lanzaboote"):
        t.assertEqual(booted(), secure_boot)
        machine.succeed("grep -qx lanzaboote /etc/vmtest-installer")
        t.assertIn("nixos-generation-2-", current_entry())

    with subtest("rollback: generation 3 has Secure Boot off, the Python installer takes the ESP back"):
        switch_to(plain)
        esp()
        python_entry(3)

    with subtest("runbook: remove lanzaboote's UKIs, which the Python installer does not collect"):
        machine.succeed("rm -f /boot/EFI/Linux/nixos-generation-*.efi")
        machine.fail("ls /boot/EFI/Linux/nixos-*.efi")
        esp()

    machine.reboot()
    machine.wait_for_unit("multi-user.target")

    with subtest("generation 3 boots through systemd-boot again"):
        t.assertEqual(booted(), plain)
        machine.succeed("grep -qx systemd-boot /etc/vmtest-installer")
        t.assertIn(".conf", current_entry())
  '';
}
