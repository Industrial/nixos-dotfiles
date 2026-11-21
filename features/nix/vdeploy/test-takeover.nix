# The LIVE take-over from comin to vdeploy, and back (GH-160, brief rule 17).
#
#   nix build .#checks.x86_64-linux.vdeploy-takeover-vm
#
# A real comin cannot run here: it would evaluate a flake from a git remote, which means
# all of nixpkgs, offline. A `comin` stand-in has exactly the shape that matters, taken from
# comin's nix/module.nix and internal/executor/utils.go:
#   - X-RestartIfChanged=false, Restart=always, wantedBy multi-user, the default KillMode;
#   - it sets its own profile (system-profiles/comin) to the target, then runs
#     <target>/bin/switch-to-configuration switch as its DIRECT CHILD, with stdout and stderr
#     captured by itself (a pipe into the deployer, as Go's exec.Command with
#     Stdout/Stderr writers is);
#   - afterwards it compares `systemctl cat comin.service` before and after, and exits 0
#     when it changed (comin's self-restart path, manager.go os.Exit(0)).
#
# The machine boots WITHOUT the take-over: the stand-in deploys, vdeploy is in observe mode
# (drakkar after #159). Generations are specialisations of the boot generation:
#   takeover  vdeploy mode = "deploy": comin's tombstone, vdeploy deploys
#   good      takeover, with the web service serving another page
#   naive     a take-over WITHOUT the tombstone (the stand-in simply dropped): the negative
#             control, run last, which shows the test can see the trap
#
# Covered, with a non-root user checked after every switch (alice: a store query through
# the daemon, and the web page):
#   1. INTO: the stand-in applies `takeover`; its switch runs to the end, comin stays down,
#      vdeploy runs in deploy mode;
#   2. vdeploy deploys after the take-over: `vdeploy-apply good` (the daemon's own transient
#      unit) switches, health-checked, and writes the system profile;
#   3. OUT, the rollback option: `vdeploy-apply <boot generation>` (observe mode, comin back)
#      completes although the switch restarts vdeploy.service; the stand-in runs again;
#   4. vdeploy refuses to switch while comin is active;
#   5. the negative control: the stand-in applying `naive` is killed by its own switch.
{pkgs}: let
  inherit (pkgs) busybox;
  dir = "/var/lib/prometheus-node-exporter-text";
  shimDir = "/run/comin-shim";
in
  pkgs.testers.runNixOSTest {
    name = "vdeploy-takeover-vm";

    nodes.machine = {
      config,
      lib,
      ...
    }: let
      inherit (config.vmtest) gen;
      # comin's stand-in: one request at a time, from ${shimDir}/request.
      shim = pkgs.writeShellScript "comin-shim" ''
        set -u
        mkdir -p ${shimDir}
        echo started > ${shimDir}/state
        unit() { ${config.systemd.package}/bin/systemctl cat comin.service 2>/dev/null | ${pkgs.coreutils}/bin/sha256sum; }
        while :; do
          if [ -f ${shimDir}/request ]; then
            target=$(cat ${shimDir}/request)
            rm -f ${shimDir}/request ${shimDir}/result
            before=$(unit)
            mkdir -p /nix/var/nix/profiles/system-profiles
            ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system-profiles/comin --set "$target"
            # The switch is our child, and its output comes back to us through a pipe.
            out=$("$target/bin/switch-to-configuration" switch 2>&1)
            rc=$?
            printf '%s\n' "$out" > ${shimDir}/log
            echo "$rc" > ${shimDir}/result
            if [ "$(unit)" != "$before" ]; then
              echo "comin-shim: my unit changed, exiting" >&2
              exit 0
            fi
          fi
          sleep 1
        done
      '';
    in {
      imports = [./default.nix ../vhealth/default.nix];

      options.vmtest.gen = lib.mkOption {
        type = lib.types.enum ["base" "takeover" "good" "naive"];
        default = "base";
      };

      config = {
        system.switch.enable = true;
        features.nix.vdeploy = {
          mode =
            if builtins.elem gen ["takeover" "good"]
            then "deploy"
            else "observe";
          # Nothing to poll here: the applies are driven by the test, through vdeploy-apply.
          url = "/srv/nothing";
          interval = "1h";
          healthWindow = "10s";
          dotfiles.enable = false;
        };

        # The stand-in deploys in the boot generation; `naive` drops it with no tombstone.
        systemd.services.comin = lib.mkIf (gen == "base") {
          description = "comin stand-in: switch-to-configuration as a direct, piped child";
          wantedBy = ["multi-user.target"];
          restartIfChanged = false;
          serviceConfig = {
            ExecStart = shim;
            Restart = "always";
          };
        };

        # A service with a probe, so every generation has a health check that means something.
        environment.etc."web/index.html".text = "${gen}\n";
        systemd.services.web = {
          wantedBy = ["multi-user.target"];
          serviceConfig.ExecStart = "${busybox}/bin/httpd -f -p 127.0.0.1:8080 -h /etc/web";
        };
        features.nix.vhealth = {
          interval = "5s";
          probes.web = {
            type = "http";
            url = "http://127.0.0.1:8080/index.html";
            bodyContains = gen;
            timeout = 2000;
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
          takeover.configuration.vmtest.gen = "takeover";
          good.configuration.vmtest.gen = "good";
          naive.configuration.vmtest.gen = "naive";
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
      takeover, good, naive = gen("takeover"), gen("good"), gen("naive")

      def current():
          return machine.succeed("readlink -f /run/current-system").strip()

      def non_root(page):
          machine.succeed("timeout 60 su - alice -c 'nix-store --store daemon -q --hash /run/current-system'")
          body = machine.succeed("timeout 30 su - alice -c 'curl -sf http://127.0.0.1:8080/index.html'").strip()
          t.assertEqual(body, page)

      def last():
          return json.loads(machine.succeed("cat /var/lib/vdeploy/last.json"))

      def comin_switch(target):
          machine.succeed(f"echo {target} > ${shimDir}/request")

      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("comin.service")
      machine.wait_for_unit("vdeploy.service")
      machine.wait_until_succeeds("test -f ${shimDir}/state", timeout=60)

      with subtest("the boot generation: comin deploys, vdeploy observes"):
          t.assertEqual(current(), base)
          machine.succeed("journalctl -u vdeploy -o cat | grep -q 'observe mode'")
          non_root("base")

      with subtest("INTO the take-over, applied by comin: its switch runs to the end"):
          comin_switch(takeover)
          machine.wait_until_succeeds("test -f ${shimDir}/result", timeout=300)
          t.assertEqual(machine.succeed("cat ${shimDir}/result").strip(), "0")
          machine.succeed(f"journalctl -o cat | grep -qF 'finished switching to system configuration {takeover}'")
          t.assertEqual(current(), takeover)
          # comin left on its own (its unit changed) and the tombstone keeps it down.
          machine.wait_until_fails("systemctl is-active comin.service", timeout=60)
          # Whichever came first: comin's own exit, or vdeploy stopping it once the switch was over.
          print(machine.succeed("journalctl -u comin -u vdeploy -o cat | grep -E 'my unit changed|retired comin|comin.service is not running'"))
          machine.sleep(15)
          machine.fail("systemctl is-active comin.service")
          machine.succeed("systemctl cat comin.service | grep -qx 'Restart=no'")
          # vdeploy deploys now, and retired comin first.
          machine.wait_until_succeeds("journalctl -u vdeploy -o cat | grep -q 'deploy mode for machine'", timeout=60)
          machine.wait_until_succeeds("journalctl -u vdeploy -o cat | grep -q 'vdeploy deploys this host'", timeout=60)
          machine.wait_until_succeeds("grep -qx 'vdeploy_deploy_mode 1' ${dir}/vdeploy.prom", timeout=120)
          non_root("takeover")

      with subtest("vdeploy deploys after the take-over: switched, health-checked, the boot profile written"):
          machine.succeed(f"vdeploy-apply {good}")
          t.assertEqual(current(), good)
          l = last()
          t.assertEqual((l["result"], l["toplevel"], l["prev"]), ("switched", good, takeover))
          t.assertTrue(l["health"]["healthy"], l)
          t.assertEqual(machine.succeed("readlink -f /nix/var/nix/profiles/system").strip(), good)
          machine.fail("test -e /var/lib/vdeploy/inflight.json")
          machine.fail("systemctl is-active comin.service")
          non_root("good")

      with subtest("OUT again, the rollback option, applied by vdeploy: the switch survives its own daemon"):
          machine.succeed(f"vdeploy-apply {base}")
          t.assertEqual(current(), base)
          t.assertEqual(last()["result"], "switched")
          machine.succeed(f"journalctl -o cat | grep -qF 'finished switching to system configuration {base}'")
          # comin is back from its own wantedBy, and vdeploy observes again.
          machine.wait_for_unit("comin.service")
          machine.wait_until_succeeds("journalctl -u vdeploy -o cat | tail -n 20 | grep -q 'observe mode'", timeout=60)
          machine.succeed("systemctl cat comin.service | grep -q 'comin stand-in'")
          non_root("base")

      with subtest("nothing switches while comin is active"):
          machine.fail(f"vdeploy apply --toplevel {good} --state-dir /tmp/refused --comin-unit comin.service")
          t.assertEqual(current(), base)
          refused = json.loads(machine.succeed("cat /tmp/refused/last.json"))
          t.assertEqual(refused["result"], "refused")
          t.assertIn("comin.service is active", refused["reason"])

      with subtest("negative control: a take-over that just drops comin's unit kills its own switch"):
          comin_switch(naive)
          machine.sleep(60)
          machine.fail("test -f ${shimDir}/result")
          machine.fail(f"journalctl -o cat | grep -qF 'finished switching to system configuration {naive}'")
          machine.fail("systemctl is-active comin.service")
    '';
  }
