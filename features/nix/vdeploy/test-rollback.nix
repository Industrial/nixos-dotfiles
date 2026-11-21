# vdeploy's apply transaction against a forced-failing health check (GH-160).
#
#   nix build .#checks.x86_64-linux.vdeploy-rollback-vm
#
# The machine runs vdeploy in deploy mode with vhealth, and a web service with an HTTP
# probe. Generations are specialisations of the boot generation:
#   good     the web page changes; its probe expects the new page
#   broken   adds `liar`, a unit systemd reports active while nothing listens on its port,
#            and a critical TCP probe on that port: unhealthy whatever systemd says
#   stuck    a critical probe on a port nothing serves, to interrupt an apply mid-check
#
# Applies go through `vdeploy-apply`, the daemon's own transient unit (vdeploy-apply).
# Covered, with a non-root user (alice) checked after every switch:
#   1. a healthy generation is switched to and becomes the system profile's newest;
#   2. a forced-failing health check rolls back: the previous generation runs again, the
#      system profile (the boot default) never moved, the reason names the failing probe,
#      the generation is marked bad, and the metrics count the rollback;
#   3. the bad generation is refused when asked again, with no switch;
#   4. an apply killed in its health window leaves inflight.json; the next apply finishes
#      the decision for it (here: roll back).
{pkgs}: let
  inherit (pkgs) busybox;
  dir = "/var/lib/prometheus-node-exporter-text";
in
  pkgs.testers.runNixOSTest {
    name = "vdeploy-rollback-vm";

    nodes.machine = {
      config,
      lib,
      ...
    }: let
      inherit (config.vmtest) gen;
    in {
      imports = [./default.nix ../vhealth/default.nix];

      options.vmtest.gen = lib.mkOption {
        type = lib.types.enum ["base" "good" "broken" "stuck"];
        default = "base";
      };

      config = {
        system.switch.enable = true;
        features.nix.vdeploy = {
          mode = "deploy";
          url = "/srv/nothing";
          interval = "1h";
          healthWindow = "10s";
          dotfiles.enable = false;
        };

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
            }
            // lib.optionalAttrs (gen == "stuck") {
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
        };
        services.prometheus.exporters.node.enable = true;
        environment.systemPackages = [pkgs.curl pkgs.jq];
        virtualisation = {
          memorySize = 2048;
          cores = 2;
        };

        specialisation = lib.mkIf (gen == "base") {
          good.configuration.vmtest.gen = "good";
          broken.configuration.vmtest.gen = "broken";
          stuck.configuration.vmtest.gen = "stuck";
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
      good, broken, stuck = gen("good"), gen("broken"), gen("stuck")

      def current():
          return machine.succeed("readlink -f /run/current-system").strip()

      def profile():
          return machine.succeed("readlink -f /nix/var/nix/profiles/system").strip()

      def last():
          return json.loads(machine.succeed("cat /var/lib/vdeploy/last.json"))

      def metric(line):
          machine.succeed(f"grep -qxF '{line}' ${dir}/vdeploy-apply.prom")

      def non_root(page):
          machine.succeed("timeout 60 su - alice -c 'nix-store --store daemon -q --hash /run/current-system'")
          body = machine.succeed("timeout 30 su - alice -c 'curl -sf http://127.0.0.1:8080/index.html'").strip()
          t.assertEqual(body, page)

      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("vdeploy.service")
      machine.wait_for_unit("web.service")
      # comin never ran here: the tombstone is inactive and vdeploy says so.
      machine.wait_until_succeeds("journalctl -u vdeploy -o cat | grep -q 'vdeploy deploys this host'", timeout=60)
      machine.fail("systemctl is-active comin.service")
      non_root("base")

      with subtest("a healthy generation is switched to, then made the boot default"):
          machine.succeed(f"vdeploy-apply {good}")
          t.assertEqual(current(), good)
          t.assertEqual(profile(), good)
          l = last()
          t.assertEqual((l["result"], l["prev"]), ("switched", base), l)
          t.assertTrue(l["health"]["healthy"], l)
          metric('vdeploy_last_result{result="switched"} 1')
          machine.fail("test -e /nix/var/nix/gcroots/vdeploy/candidate")
          non_root("good")

      with subtest("a forced-failing health check rolls back, and the boot default never moves"):
          # The liar is active per systemd; only the probe sees that nothing serves.
          machine.fail(f"vdeploy-apply {broken}")
          t.assertEqual(current(), good)
          t.assertEqual(profile(), good)
          l = last()
          t.assertEqual((l["result"], l["toplevel"], l["prev"]), ("rolled-back", broken, good), l)
          t.assertEqual(l["health"]["failing"], ["dead-port"], l)
          t.assertIn("dead-port", l["reason"])
          machine.succeed(f"test -f /var/lib/vdeploy/bad/$(basename {broken})")
          metric("vdeploy_rollbacks_total 1")
          metric('vdeploy_last_result{result="rolled-back"} 1')
          # Back on good, the liar is gone again.
          machine.fail("systemctl is-active liar.service")
          machine.succeed(f"journalctl -u vdeploy-apply -o cat | grep -qF 'rolled back from {broken} to {good}'")
          non_root("good")

      with subtest("the rolled-back generation is refused when asked again, with no switch"):
          machine.fail(f"vdeploy-apply {broken}")
          t.assertEqual(current(), good)
          l = last()
          t.assertEqual(l["result"], "refused", l)
          t.assertIn("marked bad", l["reason"])
          non_root("good")

      with subtest("an apply killed in its health window is decided by the next one"):
          machine.succeed(f"systemd-run --unit=apply-bg --collect vdeploy-apply {stuck}")
          machine.wait_until_succeeds("test -e /var/lib/vdeploy/inflight.json", timeout=60)
          machine.wait_until_succeeds("pgrep -f 'vhealth check'", timeout=60)
          machine.succeed("systemctl kill --signal=SIGKILL vdeploy-apply.service")
          machine.wait_until_fails("systemctl is-active vdeploy-apply.service", timeout=30)
          # Killed after the switch and before the decision: running stuck, nothing written.
          t.assertEqual(current(), stuck)
          t.assertEqual(profile(), good)
          inflight = json.loads(machine.succeed("cat /var/lib/vdeploy/inflight.json"))
          t.assertEqual((inflight["toplevel"], inflight["prev"]), (stuck, good))
          # The next apply (here with nothing new to apply) finishes it: unhealthy, so back.
          machine.succeed("vdeploy-apply")
          t.assertEqual(current(), good)
          t.assertEqual(profile(), good)
          machine.fail("test -e /var/lib/vdeploy/inflight.json")
          machine.succeed(f"test -f /var/lib/vdeploy/bad/$(basename {stuck})")
          machine.succeed(f"journalctl -u vdeploy-apply -o cat | grep -qF 'resuming the interrupted apply of {stuck}'")
          metric("vdeploy_rollbacks_total 2")
          non_root("good")

      with subtest("the history holds every outcome"):
          history = [json.loads(l)["result"] for l in machine.succeed("cat /var/lib/vdeploy/deploys.jsonl").splitlines()]
          # The resume records its own outcome; an apply with nothing new to apply adds none.
          t.assertEqual(history, ["switched", "rolled-back", "refused", "rolled-back"])
    '';
  }
