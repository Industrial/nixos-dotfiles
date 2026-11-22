# vdeploy's boot-default rule through a REAL reboot (GH-225): a crash during the health
# check boots the previous generation.
#
#   nix build .#checks.x86_64-linux.vdeploy-crash-vm
#
# `vdeploy apply` switches a new generation in with `switch-to-configuration test` and makes
# it the boot default (`nix-env -p system --set`, then `switch-to-configuration boot`) only
# after vhealth passes. So a crash anywhere in the health window must boot the generation
# that ran before. The other vdeploy VM tests boot the kernel directly; this one boots the
# way drakkar and mimir do: OVMF (EFI), systemd-boot from the ESP, the kernel the loader
# entry names (virtualisation.useBootLoader, the pattern of features/nixos/boot/test.nix,
# #194). The disk and the ESP survive the crash, so what boots is what the ESP says.
#
# The node is mimir's hardening: the STIG base-safe profile, and the Nix daemon restricted
# to wheel (and vhealth), as features/nixos/users sets on every host. Generations are
# specialisations of the boot generation, and their closures are in the image:
#   good   the web page changes; its probe expects the new page (healthy)
#   slow   adds a critical probe on a port nothing serves, with a 10-minute health window:
#          the apply sits in its health window until the test pulls the plug
#
# Covered, with a non-root user (alice, in wheel like tom) checked after every boot:
#   1. the boot generation: booted through systemd-boot, the system profile's generation 1;
#   2. the control, so the test can see a boot default move: a healthy apply of `good` makes
#      it generation 2 and the loader's default, and a reboot boots `good`;
#   3. the crash: an apply of `slow` is in its health window (slow is running, inflight.json
#      written, vhealth checking); the system profile and the loader default have not
#      moved; the VM is killed (a power cut, no shutdown);
#   4. after the crash: the firmware boots `good`, the previous generation; `slow` is not
#      the boot default and has no generation or loader entry; vdeploy's start-up resume
#      sees the host on `good` and drops the interrupted apply.
{pkgs}: let
  inherit (pkgs) busybox;
in
  pkgs.testers.runNixOSTest {
    name = "vdeploy-crash-vm";

    nodes.machine = {
      config,
      lib,
      ...
    }: let
      inherit (config.vmtest) gen;
    in {
      imports = [./default.nix ../vhealth/default.nix ../../security/stig/profiles/base-safe.nix];

      options.vmtest.gen = lib.mkOption {
        type = lib.types.enum ["base" "good" "slow"];
        default = "base";
      };

      config = {
        # EFI, systemd-boot, the kernel from the loader entry: the hosts' boot path.
        virtualisation = {
          useBootLoader = true;
          useEFIBoot = true;
          memorySize = 2048;
          cores = 2;
          diskSize = 4096;
        };
        boot.loader.systemd-boot.enable = true;
        boot.loader.timeout = 0;

        # qemu-vm turns timesyncd off; base-safe's V-268151 turns it on. The control wins here.
        services.timesyncd.enable = lib.mkForce true;
        system.switch.enable = true;
        features.nix.vdeploy = {
          mode = "deploy";
          url = "/srv/nothing";
          interval = "1h";
          # Long enough that `slow` is still in its window when the plug is pulled.
          healthWindow = "10m";
          dotfiles.enable = false;
        };

        nix.settings.allowed-users = ["@wheel"];
        features.nix.vhealth.restrictedNixUsers = true;

        environment.etc."web/index.html".text = "${gen}\n";
        systemd.services.web = {
          wantedBy = ["multi-user.target"];
          serviceConfig.ExecStart = "${busybox}/bin/httpd -f -p 127.0.0.1:8080 -h /etc/web";
        };
        features.nix.vhealth = {
          interval = "5s";
          probes =
            {
              web = {
                type = "http";
                url = "http://127.0.0.1:8080/index.html";
                bodyContains = gen;
                timeout = 2000;
              };
            }
            // lib.optionalAttrs (gen == "slow") {
              never-up = {
                type = "tcp";
                host = "127.0.0.1";
                port = 8082;
                timeout = 1000;
              };
            };
        };

        nix.settings.experimental-features = ["nix-command"];
        users.users.alice = {
          isNormalUser = true;
          uid = 1000;
          extraGroups = ["wheel"];
        };
        services.prometheus.exporters.node.enable = true;
        environment.systemPackages = [pkgs.curl pkgs.jq];

        specialisation = lib.mkIf (gen == "base") {
          good.configuration.vmtest.gen = "good";
          slow.configuration.vmtest.gen = "slow";
        };
      };
    };

    testScript = {nodes, ...}: let
      base = nodes.machine.system.build.toplevel;
    in ''
      import json

      base = "${base}"
      def gen(name):
          return machine.succeed(f"readlink -f {base}/specialisation/{name}").strip()

      def booted():
          return machine.succeed("readlink -f /run/booted-system").strip()

      def current():
          return machine.succeed("readlink -f /run/current-system").strip()

      def profile():
          return machine.succeed("readlink -f /nix/var/nix/profiles/system").strip()

      def generations():
          return machine.succeed("ls /nix/var/nix/profiles | grep -E '^system-[0-9]+-link$' | sort -V").split()

      def loader_default():
          conf = machine.succeed("cat /boot/loader/loader.conf")
          for line in conf.splitlines():
              if line.startswith("default "):
                  return line.split(" ", 1)[1].strip()
          raise Exception(f"loader.conf has no default:\n{conf}")

      def entry_init(entry):
          # The loader entry's kernel command line names the generation it boots.
          return machine.succeed(f"grep -o 'init=[^ ]*' /boot/loader/entries/{entry}").strip().removeprefix("init=").removesuffix("/init")

      def entries():
          # The installer names entries nixos-<sha256 of the contents>.conf, so an unchanged
          # set of names is an unchanged set of entries. Generation 1's include its
          # specialisations (good and slow, by construction).
          names = sorted(machine.succeed("ls /boot/loader/entries/").split())
          print(names)
          return names

      def no_generation_for(system, before):
          # The apply wrote no entry: the same entries as before it, and no generation 3.
          t.assertEqual(entries(), before)
          machine.fail("grep -l '^version Generation 3 ' /boot/loader/entries/*.conf")

      def non_root(page):
          machine.succeed("timeout 60 su - alice -c 'nix-store --store daemon -q --hash /run/current-system'")
          body = machine.succeed("timeout 30 su - alice -c 'curl -sf http://127.0.0.1:8080/index.html'").strip()
          t.assertEqual(body, page)

      def up():
          machine.wait_for_unit("multi-user.target")
          machine.wait_for_unit("vdeploy.service")
          machine.wait_for_unit("web.service")

      machine.start(allow_reboot=True)
      up()
      good, slow = gen("good"), gen("slow")

      with subtest("the boot generation boots through EFI and systemd-boot"):
          t.assertEqual(booted(), base)
          t.assertEqual(profile(), base)
          t.assertEqual(generations(), ["system-1-link"])
          print(machine.succeed("bootctl status 2>&1 || true"))
          t.assertEqual(entry_init(loader_default()), base)
          non_root("base")

      with subtest("control: a healthy apply moves the boot default, and a reboot boots it"):
          machine.succeed(f"vdeploy-apply {good}")
          l = json.loads(machine.succeed("cat /var/lib/vdeploy/last.json"))
          t.assertEqual((l["result"], l["toplevel"]), ("switched", good), l)
          t.assertEqual(profile(), good)
          t.assertEqual(generations(), ["system-1-link", "system-2-link"])
          t.assertEqual(entry_init(loader_default()), good)
          machine.reboot()
          up()
          t.assertEqual(booted(), good)
          non_root("good")

      with subtest("the crash: an apply in its health window, then the plug is pulled"):
          before = entries()
          machine.succeed(f"systemd-run --unit=apply-bg --collect vdeploy-apply {slow}")
          machine.wait_until_succeeds("test -e /var/lib/vdeploy/inflight.json", timeout=120)
          machine.wait_until_succeeds("pgrep -f 'vhealth check'", timeout=120)
          inflight = json.loads(machine.succeed("cat /var/lib/vdeploy/inflight.json"))
          t.assertEqual((inflight["toplevel"], inflight["prev"]), (slow, good))
          t.assertEqual(current(), slow)
          machine.succeed("systemctl is-active vdeploy-apply.service")
          # Still deciding: nothing written to the boot entries.
          t.assertEqual(profile(), good)
          t.assertEqual(generations(), ["system-1-link", "system-2-link"])
          t.assertEqual(entry_init(loader_default()), good)
          no_generation_for(slow, before)
          # The ledger reaches the disk (the decision about the boot path does not need it).
          machine.succeed("sync")
          machine.crash()

      machine.start(allow_reboot=True)
      up()

      with subtest("after the crash: the previous generation boots, the new one is not the default"):
          t.assertEqual(booted(), good)
          t.assertEqual(current(), good)
          t.assertEqual(profile(), good)
          t.assertEqual(generations(), ["system-1-link", "system-2-link"])
          t.assertEqual(entry_init(loader_default()), good)
          no_generation_for(slow, before)
          # vdeploy's start-up resume finds the host on good and drops the interrupted apply.
          machine.wait_until_succeeds(f"journalctl -b -o cat | grep -qF 'an interrupted apply of {slow} left the host on {good}: nothing to resume'", timeout=120)
          machine.wait_until_fails("test -e /var/lib/vdeploy/inflight.json", timeout=60)
          non_root("good")
    '';
  }
