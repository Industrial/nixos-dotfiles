# vdaemon-proxy's conformance mode (#183) in a VM, switched into and out of a RUNNING
# system (brief rule 17), with builds and garbage collections racing the queries.
#
#   nix build .#checks.x86_64-linux.vdaemon-proxy-conformance-vm
#
# The machine boots without the proxy (with common/nix-daemon-listen.nix, which every
# host carries). It switches live into the `conformance` specialisation (the proxy,
# conformance on); an untrusted user's Nix must work through it. Then, at once:
#
#   alice   builds 30 fresh derivations through the daemon, none of them rooted
#   root    collects garbage, through the daemon and directly, again and again
#   alice   queries: path-info of the system's closure, validity, references and
#           referrers of the builds that come and go
#
# Every read-only op is checked against the native answer, and the counters' textfile
# (readable by alice) must show thousands of checks and no difference. Then the machine
# switches back out, and alice's Nix must work directly again.
{pkgs}: let
  inherit (pkgs) busybox;
  # One derivation per `n`, built in the sandbox from busybox alone.
  expr = pkgs.writeText "conformance.nix" ''
    {n}: derivation {
      name = "vdaemon-conformance-''${n}";
      system = builtins.currentSystem;
      builder = "''${builtins.storePath ${busybox}}/bin/sh";
      args = ["-c" "echo ''${n} > $out"];
    }
  '';
  metrics = "/run/vdaemon-proxy/conformance.prom";

  # alice: the builds, one output path per line in /tmp/built.
  builds = pkgs.writeShellScript "conformance-builds" ''
    for i in $(seq 1 30); do
      nix-build --no-out-link --argstr n "$i-$RANDOM" ${expr} >> /tmp/built 2>> /tmp/builds.err || true
    done
  '';
  # root: collections, through the daemon (the proxy forwards CollectGarbage) and direct.
  collections = pkgs.writeShellScript "conformance-gc" ''
    for i in $(seq 1 20); do
      nix-store --store daemon --gc > /dev/null 2>&1 || true
      nix-collect-garbage > /dev/null 2>&1 || true
      sleep 1
    done
  '';
  # alice: the queries, over the system's closure and the builds as they come and go.
  queries = pkgs.writeShellScript "conformance-queries" ''
    sys=$(readlink -f /run/current-system)
    for i in $(seq 1 25); do
      nix --extra-experimental-features nix-command path-info -r "$sys" > /dev/null 2>&1 || true
      touch /tmp/built
      built=$(tail -n 20 /tmp/built)
      nix-store --check-validity --print-invalid $built /nix/store/00000000000000000000000000000000-nope > /dev/null 2>&1 || true
      for p in $built; do
        nix-store -q --references "$p" > /dev/null 2>&1 || true
        nix-store -q --referrers "$p" > /dev/null 2>&1 || true
        nix --extra-experimental-features nix-command path-info --json "$p" > /dev/null 2>&1 || true
      done
      nix-store -q --referrers ${busybox} > /dev/null 2>&1 || true
    done
  '';
in
  pkgs.testers.runNixOSTest {
    name = "vdaemon-proxy-conformance";

    nodes.machine = {
      imports = [../../../common/nix-daemon-listen.nix];
      nix.settings.experimental-features = ["nix-command"];
      # busybox for the builder; the expression and the workload scripts too, so the
      # collections the test runs do not delete them.
      system.extraDependencies = [busybox expr builds collections queries];
      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
      };
      virtualisation.memorySize = 1536;
      specialisation.conformance.configuration = {
        imports = [./default.nix];
        features.nix.vdaemon-proxy.conformance = true;
      };
    };

    testScript = {nodes, ...}: let
      base = nodes.machine.system.build.toplevel;
    in ''
      import re

      def alice(cmd):
          return machine.succeed(f"timeout 120 su - alice -c '{cmd}'")

      def counters():
          text = alice("cat ${metrics}")
          found = re.search(r"^vdaemon_conformance_diffs_total (\d+)$", text, re.M)
          assert found is not None, text
          diffs = int(found.group(1))
          checks = {}
          for op, verdict, n in re.findall(r'^vdaemon_conformance_checks_total\{op="(\w+)",verdict="(\w+)"\} (\d+)$', text, re.M):
              checks[(op, verdict)] = int(n)
          return diffs, checks, text

      def checked(checks):
          return sum(n for (op, verdict), n in checks.items() if verdict in ("match", "raced"))

      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("nix-daemon-listen.service")

      with subtest("without the feature, Nix is direct"):
          alice("nix-store -q --hash /run/current-system")
          machine.fail("systemctl is-active vdaemon-proxy.socket")

      with subtest("a live switch into conformance mode hands the socket to the proxy"):
          machine.succeed("${base}/specialisation/conformance/bin/switch-to-configuration test")
          machine.succeed("systemctl is-active vdaemon-proxy.socket nix-daemon-listen.service")
          alice("nix-store -q --hash /run/current-system")
          machine.wait_until_succeeds("journalctl -u vdaemon-proxy.service -o cat | grep -F 'conformance: on'", timeout=30)
          machine.wait_until_succeeds("journalctl -u vdaemon-proxy.service -o cat | grep -F '\"uid\":1000'", timeout=30)
          # The counters are a user's to read.
          machine.wait_until_succeeds("su - alice -c 'test -r ${metrics}'", timeout=60)

      with subtest("builds and garbage collections race the queries"):
          machine.succeed("su - alice -c 'touch /tmp/built'")
          machine.succeed(
              "(su - alice -c ${builds} & ${collections} & su - alice -c ${queries} & wait) > /tmp/workload.log 2>&1"
          )
          print(machine.succeed("wc -l < /tmp/built; tail -n 5 /tmp/builds.err || true"))
          # The textfile is rewritten every 30 s; wait for the one after the workload.
          machine.succeed("touch /tmp/after-workload")
          machine.wait_until_succeeds("test ${metrics} -nt /tmp/after-workload", timeout=90)
          diffs, checks, text = counters()
          print(text)
          print(machine.succeed("journalctl -u vdaemon-proxy.service -o cat | grep -F '\"event\":\"conformance_diff\"' | head -n 20 || true"))
          assert diffs == 0, f"{diffs} conformance differences"
          assert checked(checks) >= 2000, f"only {checked(checks)} ops checked"
          for op in ("QueryPathInfo", "IsValidPath", "QueryReferrers"):
              assert checks.get((op, "match"), 0) > 0, f"no {op} checked"
          # The builds really did come and go.
          assert int(machine.succeed("wc -l < /tmp/built").strip()) >= 20
          machine.succeed("journalctl -u vdaemon-proxy.service -o cat | grep -F '\"op\":\"CollectGarbage\"'")

      with subtest("the client always gets the daemon's answer"):
          valid = alice("nix-store --check-validity --print-invalid /run/current-system /nix/store/00000000000000000000000000000000-nope 2>&1 || true")
          assert "00000000000000000000000000000000-nope" in valid, valid
          assert "Trusted: 0" in alice("nix store info 2>&1"), "alice must stay untrusted"

      with subtest("a live switch back out returns the socket to nix-daemon"):
          machine.succeed("${base}/bin/switch-to-configuration test")
          machine.fail("systemctl is-active vdaemon-proxy.socket")
          machine.succeed("systemctl is-active nix-daemon-listen.service")
          alice("nix-store -q --hash /run/current-system")
          alice("nix --extra-experimental-features nix-command path-info -r /run/current-system > /dev/null")
    '';
  }
