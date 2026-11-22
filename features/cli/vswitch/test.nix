# vswitch, the local rebuild (GH-241), switching a real system as a non-root user:
#
#   nix build .#checks.x86_64-linux.vswitch-vm
#
# The node is drakkar-like: nix.settings.allowed-users = ["@wheel"] (features/nixos/users on
# every host), vhealth with its probes, and alice in wheel like tom. vswitch is run by alice;
# only the activation is elevated (sudo, here without a password), in vdeploy's transient
# unit. The generations are specialisations of the boot generation, handed over with
# --toplevel (the VM has no flake to build from; the build step is covered by the crate's
# tests):
#   good     the web page changes; its probe expects the new page
#   broken   adds `liar`, a unit systemd reports active while nothing listens on its port, and
#            a critical TCP probe on that port: unhealthy whatever systemd says
#
# Covered, with the non-root user checked after every step (the daemon answers alice, the
# web page is the generation's):
#   1. a vhealth failure rolls back: switch to broken exits non-zero, the previous generation
#      runs again, the boot default never moved, and broken is marked bad in vdeploy's ledger;
#   2. the bad generation is refused when asked again, with no switch;
#   3. a healthy switch is kept: running and boot default both move;
#   4. switching to the generation that runs is a no-op that needs no root;
#   5. test activates without touching the boot default; boot moves only the boot default;
#   6. the activation ran in the vdeploy-apply unit, and as alice nothing was asked of sudo
#      for build-only verbs (vswitch build --toplevel needs no root at all).
{pkgs}: let
  inherit (pkgs) busybox;

  node = {
    config,
    lib,
    ...
  }: let
    inherit (config.vmtest) gen;
  in {
    imports = [./default.nix ../../nix/vhealth/default.nix];

    options.vmtest.gen = lib.mkOption {
      type = lib.types.enum ["base" "good" "broken"];
      default = "base";
    };

    config = {
      system.switch.enable = true;

      # drakkar's and mimir's restriction (features/nixos/users/default.nix). That feature is
      # detected by vhealth; here it is set by hand, so vhealth is told.
      nix.settings.allowed-users = ["@wheel"];
      features.nix.vhealth.restrictedNixUsers = true;

      environment.etc."web/index.html".text = "${
        if gen == "base"
        then "base"
        else "good"
      }\n";
      systemd.services.web = {
        wantedBy = ["multi-user.target"];
        serviceConfig.ExecStart = "${busybox}/bin/httpd -f -p 127.0.0.1:8080 -h /etc/web";
      };
      # The liar: `active (running)` to systemd, and nothing listens on its port.
      systemd.services.liar = lib.mkIf (gen == "broken") {
        wantedBy = ["multi-user.target"];
        serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
      };
      features.nix.vhealth = {
        interval = "5s";
        probes =
          {
            web = {
              type = "http";
              url = "http://127.0.0.1:8080/index.html";
              bodyContains =
                if gen == "base"
                then "base"
                else "good";
              timeout = 2000;
            };
          }
          // lib.optionalAttrs (gen == "broken") {
            dead-port = {
              type = "tcp";
              host = "127.0.0.1";
              port = 8081;
              timeout = 1000;
            };
          };
      };

      nix.settings.experimental-features = ["nix-command"];
      # In wheel, like tom: the only users the restricted daemon serves, and sudo's.
      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
        extraGroups = ["wheel"];
      };
      security.sudo.wheelNeedsPassword = false;
      environment.systemPackages = [pkgs.curl];
      virtualisation = {
        memorySize = 2048;
        cores = 2;
      };

      specialisation = lib.mkIf (gen == "base") {
        good.configuration.vmtest.gen = "good";
        broken.configuration.vmtest.gen = "broken";
      };
    };
  };
in
  pkgs.testers.runNixOSTest {
    name = "vswitch-vm";

    nodes.machine = node;

    testScript = ''
      import json

      def gen(name):
          base = machine.succeed("readlink -f /run/booted-system").strip()
          return machine.succeed(f"readlink -f {base}/specialisation/{name}").strip()

      def current():
          return machine.succeed("readlink -f /run/current-system").strip()

      def profile():
          return machine.succeed("readlink -f /nix/var/nix/profiles/system").strip()

      def last():
          return json.loads(machine.succeed("cat /var/lib/vdeploy/last.json"))

      def alice(cmd):
          return f"su - alice -c {json.dumps(cmd)}"

      def non_root(page):
          machine.succeed(alice("timeout 60 nix-store --store daemon -q --hash /run/current-system"))
          body = machine.succeed(alice("timeout 30 curl -sf http://127.0.0.1:8080/index.html")).strip()
          t.assertEqual(body, page)

      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("web.service")
      non_root("base")
      base = current()
      good, broken = gen("good"), gen("broken")

      with subtest("build needs no root: it only resolves and diffs"):
          out = machine.succeed(alice(f"vswitch build --toplevel {good} 2>&1"))
          t.assertIn(f"built {good}", out)
          t.assertEqual((current(), profile()), (base, base))

      with subtest("a vhealth failure rolls back, the boot default never moves, and it is marked bad"):
          machine.fail(alice(f"vswitch switch --toplevel {broken} --health-window 10s"))
          t.assertEqual(current(), base)
          t.assertEqual(profile(), base)
          l = last()
          t.assertEqual((l["result"], l["toplevel"], l["prev"]), ("rolled-back", broken, base), l)
          t.assertEqual(l["health"]["failing"], ["dead-port"], l)
          machine.succeed(f"test -f /var/lib/vdeploy/bad/$(basename {broken})")
          machine.fail("systemctl is-active liar.service")
          machine.succeed(f"journalctl -u vdeploy-apply -o cat | grep -qF 'rolled back from {broken} to {base}'")
          non_root("base")

      with subtest("the rolled-back generation is refused when asked again, with no switch"):
          machine.fail(alice(f"vswitch switch --toplevel {broken} --health-window 10s"))
          t.assertEqual(current(), base)
          t.assertEqual(last()["result"], "refused")
          non_root("base")

      with subtest("a healthy switch is kept: running and boot default both move"):
          out = machine.succeed(alice(f"vswitch switch --toplevel {good} --health-window 30s 2>&1"))
          t.assertEqual(current(), good)
          t.assertEqual(profile(), good)
          l = last()
          t.assertEqual((l["result"], l["prev"]), ("switched", base), l)
          t.assertTrue(l["health"]["healthy"], l)
          # vdiff's report of the running system against the new one was printed first.
          t.assertIn("Closure size:", out)
          non_root("good")

      with subtest("switching to the running generation is a no-op"):
          out = machine.succeed(alice(f"vswitch switch --toplevel {good} --elevate /run/current-system/sw/bin/false 2>&1"))
          t.assertIn("nothing to switch", out)
          t.assertEqual(current(), good)

      with subtest("test activates without touching the boot default"):
          machine.succeed(alice(f"vswitch test --toplevel {base}"))
          t.assertEqual((current(), profile()), (base, good))
          non_root("base")

      with subtest("boot moves only the boot default"):
          machine.succeed(alice(f"vswitch boot --toplevel {base}"))
          t.assertEqual((current(), profile()), (base, base))
          non_root("base")

      with subtest("every activation ran in vdeploy's unit"):
          machine.succeed("journalctl -o cat | grep -qF 'vswitch switch: '")
          machine.succeed("journalctl -o cat | grep -qF 'vswitch test: '")
          machine.succeed("journalctl -o cat | grep -qF 'vswitch boot: '")
    '';
  }
