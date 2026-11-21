# NixOS VM test for features/nix/vdeploy (GH-159), observe mode.
#
#   nix build .#checks.x86_64-linux.vdeploy-vm
#
# The "fleet repository" is a local git repository (/srv/origin) holding a flake with no
# inputs. Its nixosConfigurations.machine "toplevel" is a trivial derivation that embeds the
# commit (`self.rev`) and takes 20 s to build, so every commit is a new build.
#
# Covered:
#   - a plan for the first commit: evaluated, built (nothing to substitute: the VM has no
#     substituters), diffed against /run/current-system, and logged as the switch it would
#     make; the system is never switched;
#   - commits arrive every 3 s while each build takes 20 s: every build that starts
#     finishes (none cancelled), commits in between are skipped (latest-wins), and the
#     agent converges on the newest commit;
#   - alice's ~/.dotfiles checkout is fast-forwarded to main, as alice; once she has a
#     tracked change it is refused and left alone, and the refusal is in the journal and the
#     metrics.
{pkgs}: let
  inherit (pkgs) busybox;
  dir = "/var/lib/prometheus-node-exporter-text";
  flake = pkgs.writeText "flake.nix" ''
    {
      outputs = {self}: {
        nixosConfigurations.machine.config.system.build.toplevel = derivation {
          name = "vdeploy-fake-system";
          system = "x86_64-linux";
          builder = "${busybox}/bin/sh";
          args = ["-c" "${busybox}/bin/sleep 20; ${busybox}/bin/mkdir -p $out; echo ''${self.rev or "dirty"} > $out/rev"];
        };
      };
    }
  '';
  lock = pkgs.writeText "flake.lock" ''{"nodes":{"root":{}},"root":"root","version":7}'';
in
  pkgs.testers.runNixOSTest {
    name = "vdeploy-vm";

    nodes.machine = {lib, ...}: {
      imports = [./default.nix];
      features.nix.vdeploy = {
        url = "/srv/origin";
        interval = "2s";
        dotfiles.user = "alice";
      };
      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
      };
      # Offline: nothing to substitute, so the Fetcher declines and the Builder builds.
      nix.settings = {
        substituters = lib.mkForce [];
        experimental-features = ["nix-command" "flakes"];
        # The fake toplevel's builder is busybox, named by a path without string context
        # (a pure flake evaluation cannot use builtins.storePath), so it is outside a sandbox.
        sandbox = false;
      };
      system.extraDependencies = [busybox];
      # The origin is alice's; root (vdeploy's own clone) reads it too.
      programs.git = {
        enable = true;
        config.safe.directory = "*";
      };
      services.prometheus.exporters.node.enable = true;
      environment.systemPackages = [pkgs.jq pkgs.curl];
      virtualisation = {
        cores = 2;
        memorySize = 2048;
      };
    };

    testScript = ''
      import json, time

      def alice(cmd):
          return machine.succeed(f"su - alice -c {json.dumps(cmd)}")

      def head():
          return alice("git -C /srv/origin rev-parse HEAD").strip()

      def commit(n):
          alice(f"cd /srv/origin && echo {n} > n && git add -A && git commit -qm 'commit {n}'")
          return head()

      def plan():
          return json.loads(machine.succeed("cat /var/lib/vdeploy/plan.json"))

      def metric(name):
          text = machine.succeed("cat ${dir}/vdeploy.prom")
          for line in text.splitlines():
              if line.startswith(name + " "):
                  return float(line.split()[1])
          raise Exception(f"{name} not in vdeploy.prom:\n{text}")

      def planned(sha):
          return f"jq -e '.commit == \"{sha}\"' /var/lib/vdeploy/plan.json"

      machine.wait_for_unit("multi-user.target")
      system = machine.succeed("readlink -f /run/current-system").strip()
      # The unit binds the checkout writable when it starts, so the repositories come first.
      machine.succeed("systemctl stop vdeploy")

      machine.succeed("install -d -o alice -g users /srv/origin")
      alice("git config --global user.name alice && git config --global user.email alice@example.org")
      alice("cd /srv/origin && git init -q -b main")
      machine.succeed("cp ${flake} /srv/origin/flake.nix && cp ${lock} /srv/origin/flake.lock && chown alice /srv/origin/flake.*")
      first = commit(0)
      alice("git clone -q /srv/origin /home/alice/.dotfiles")
      machine.succeed("systemctl start vdeploy")

      def eventually(line):
          machine.wait_until_succeeds(f"grep -qxF '{line}' ${dir}/vdeploy.prom", timeout=60)

      with subtest("the first commit is planned: built, diffed, logged, not switched"):
          machine.wait_until_succeeds(planned(first), timeout=300)
          p = plan()
          assert p["mode"] == "observe" and p["host"] == "machine", p
          assert p["action"] == "switch" and p["realised"] == "built", p
          assert p["running"]["toplevel"] == system, p
          assert p["diff"]["schema"] == 1, p
          assert machine.succeed(f"cat {p['out']}/rev").strip() == first
          machine.succeed("journalctl -u vdeploy -o cat | grep -q 'would switch machine'")
          machine.succeed("journalctl -u vdeploy -o cat | grep -q 'Observe mode: not switching.'")
          assert machine.succeed("readlink -f /run/current-system").strip() == system
          eventually("vdeploy_switch_pending 1")
          eventually('vdeploy_dotfiles_state{state="up-to-date"} 1')
          assert metric("vdeploy_observe_mode") == 1

      with subtest("commits faster than a build: none cancelled, the newest planned"):
          shas = []
          for n in range(1, 9):
              shas.append(commit(n))
              time.sleep(3)
          last = shas[-1]
          machine.wait_until_succeeds(planned(last), timeout=600)
          # The metrics follow at the next poll.
          time.sleep(6)
          started = metric("vdeploy_plans_started_total")
          finished = metric("vdeploy_plans_finished_total")
          skipped = metric("vdeploy_commits_skipped_total")
          failed = metric("vdeploy_plans_failed_total")
          assert started == finished, (started, finished)
          assert failed == 0, failed
          # 9 commits in all; fewer plans than that, the rest skipped (latest-wins). A
          # commit the poller never saw (two between polls) is in neither count.
          assert started < 9 and skipped >= 1, (started, skipped)
          # The poller keeps polling while a build runs (the build is an awaited child
          # process, not a blocked executor thread): a 20 s build spans ~6 commits, and the
          # poller sees them land, so most of them are counted as skipped.
          assert skipped >= 3 and started <= 5, (started, skipped)
          assert started + skipped <= 9, (started, skipped)
          history = [json.loads(l) for l in machine.succeed("cat /var/lib/vdeploy/plans.jsonl").splitlines()]
          assert [h["commit"] for h in history][-1] == last, history
          assert all(h["action"] == "switch" for h in history), history
          machine.fail("journalctl -u vdeploy -o cat | grep -qi 'cancel'")
          assert machine.succeed("readlink -f /run/current-system").strip() == system

      with subtest("the dotfiles checkout was fast-forwarded to main, as alice"):
          machine.wait_until_succeeds(f"test \"$(git -C /home/alice/.dotfiles rev-parse HEAD)\" = {last}", timeout=60)
          assert machine.succeed("stat -c %U /home/alice/.dotfiles/n").strip() == "alice"
          machine.succeed("journalctl -u vdeploy -o cat | grep -q 'fast-forwarded'")

      with subtest("a dirty checkout is refused and left alone"):
          alice("echo mine > /home/alice/.dotfiles/n")
          newer = commit(9)
          eventually('vdeploy_dotfiles_state{state="dirty"} 1')
          machine.succeed("journalctl -u vdeploy -o cat | grep -q 'refusing to fast-forward'")
          assert alice("git -C /home/alice/.dotfiles rev-parse HEAD").strip() == last
          assert alice("cat /home/alice/.dotfiles/n").strip() == "mine"
          # The agent still plans main.
          machine.wait_until_succeeds(planned(newer), timeout=300)
          assert machine.succeed("readlink -f /run/current-system").strip() == system

      with subtest("node_exporter serves the metrics"):
          machine.wait_for_open_port(9100)
          machine.succeed("curl -sf http://127.0.0.1:9100/metrics | grep -q '^vdeploy_plans_started_total '")
    '';
  }
