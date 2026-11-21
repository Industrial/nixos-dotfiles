# vdaemon-proxy answering read-only ops natively (#183, phase 3) in a VM, switched into
# and out of a RUNNING system (brief rule 17).
#
#   nix build .#checks.x86_64-linux.vdaemon-proxy-native-vm
#
# The machine boots without the proxy. Before the switch, an untrusted user records what
# Nix tells her about the system's closure, straight from nix-daemon. After a live switch
# into the `native` specialisation (all six read-only ops native), the same queries must
# give the same output, answered by the proxy ("answered":"native" in the journal),
# while builds (always forwarded) and GCs run alongside. The kill switch must send every
# op back to the daemon at once, and its removal bring them back. Then the machine
# switches out and her Nix must work directly again.
{pkgs}: let
  inherit (pkgs) busybox;
  expr = pkgs.writeText "native.nix" ''
    {n}: derivation {
      name = "vdaemon-native-''${n}";
      system = builtins.currentSystem;
      builder = "''${builtins.storePath ${busybox}}/bin/sh";
      args = ["-c" "echo ''${n} > $out"];
    }
  '';
  # What alice asks about a system closure ($1), in a fixed order: the output must not
  # depend on who answers. (Not /run/current-system: a switch repoints it.)
  queries = pkgs.writeShellScript "native-queries" ''
    sys=$1
    nix --extra-experimental-features nix-command path-info --json --json-format 1 -r "$sys"
    nix --extra-experimental-features nix-command path-info -rsS "$sys"
    nix-store -q --references "$sys"
    nix-store -q --referrers ${busybox}
    nix-store --check-validity --print-invalid $(nix-store -qR "$sys") /nix/store/00000000000000000000000000000000-nope
    nix-store -q --hash /nix/store/00000000000000000000000000000000-nope 2>&1 || true
  '';
  builds = pkgs.writeShellScript "native-builds" ''
    for i in $(seq 1 10); do
      nix-build --no-out-link --argstr n "$i-$RANDOM" ${expr} >> /tmp/built 2>> /tmp/builds.err
    done
  '';
  collections = pkgs.writeShellScript "native-gc" ''
    for i in $(seq 1 10); do
      nix-store --store daemon --gc > /dev/null 2>&1 || true
      sleep 1
    done
  '';
  # Ops answered natively so far ("answered":"native" on the op line).
  natives = "journalctl -u vdaemon-proxy.service -o cat | grep -c 'answered.:.native' || true";
in
  pkgs.testers.runNixOSTest {
    name = "vdaemon-proxy-native";

    nodes.machine = {
      imports = [../../../common/nix-daemon-listen.nix];
      nix.settings.experimental-features = ["nix-command"];
      system.extraDependencies = [busybox expr queries builds collections];
      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
      };
      virtualisation.memorySize = 1536;
      specialisation.native.configuration = {
        imports = [./default.nix];
        features.nix.vdaemon-proxy.native = ["IsValidPath" "QueryValidPaths" "QueryPathInfo" "QueryPathFromHashPart" "QueryReferrers" "NarFromPath"];
      };
    };

    testScript = {nodes, ...}: let
      base = nodes.machine.system.build.toplevel;
    in ''
      import difflib

      def alice(cmd):
          return machine.succeed(f"timeout 120 su - alice -c '{cmd}'")

      def ask():
          return alice("${queries} ${base}")

      def same(got, why):
          if got != direct:
              print("".join(list(difflib.unified_diff(direct.splitlines(True), got.splitlines(True)))[:60]))
              raise AssertionError(why)

      def natives():
          return int(machine.succeed("${natives}").strip() or "0")

      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("nix-daemon-listen.service")

      with subtest("without the feature, Nix is direct; record its answers"):
          machine.fail("systemctl is-active vdaemon-proxy.socket")
          direct = ask()
          assert "/nix/store/" in direct, direct

      with subtest("a live switch into native mode hands the socket to the proxy"):
          machine.succeed("${base}/specialisation/native/bin/switch-to-configuration test")
          machine.succeed("systemctl is-active vdaemon-proxy.socket nix-daemon-listen.service")
          alice("nix-store -q --hash /run/current-system")
          machine.wait_until_succeeds("journalctl -u vdaemon-proxy.service -o cat | grep -F 'native: IsValidPath'", timeout=30)

      with subtest("the proxy's answers are the daemon's"):
          same(ask(), "native answers differ from the daemon's")
          assert natives() > 100, f"only {natives()} ops answered natively"
          machine.succeed("journalctl -u vdaemon-proxy.service -o cat | grep -F '\"answered\":\"native\"' | grep -F '\"uid\":1000' > /dev/null")
          # Writes are never answered here.
          machine.fail("journalctl -u vdaemon-proxy.service -o cat | grep -F '\"answered\":\"native\"' | grep -E '\"op\":\"(AddToStore|AddTempRoot|BuildPaths|CollectGarbage)'")

      with subtest("builds (forwarded) and GCs run alongside native queries"):
          machine.succeed("su - alice -c 'touch /tmp/built'")
          machine.succeed("(su - alice -c ${builds} & ${collections} & su - alice -c \"${queries} ${base}\" > /dev/null & wait) > /tmp/workload.log 2>&1")
          built = machine.succeed("cat /tmp/built").split()
          assert len(built) == 10, machine.succeed("cat /tmp/built /tmp/builds.err")
          machine.succeed("journalctl -u vdaemon-proxy.service -o cat | grep -F '\"op\":\"BuildPaths\"' | grep -F '\"answered\":\"daemon\"' > /dev/null")
          machine.succeed("journalctl -u vdaemon-proxy.service -o cat | grep -F '\"op\":\"CollectGarbage\"' | grep -F '\"answered\":\"daemon\"' > /dev/null")
          # The closure is unchanged by all that, so the answers are too.
          same(ask(), "answers changed by the builds and GCs")

      with subtest("the kill switch sends every op back to the daemon at once"):
          machine.succeed("touch /run/vdaemon-proxy/forward-all")
          before = natives()
          same(ask(), "forwarded answers differ")
          assert natives() == before, "ops answered natively with the kill switch on"
          machine.succeed("rm /run/vdaemon-proxy/forward-all")
          alice("nix-store -q --references /run/current-system")
          assert natives() > before, "native answering did not come back"
          # One op at a time.
          machine.succeed("touch /run/vdaemon-proxy/forward-QueryPathInfo")
          before = natives()
          alice("nix --extra-experimental-features nix-command path-info -r /run/current-system > /dev/null")
          machine.fail("journalctl -u vdaemon-proxy.service -o cat | tail -n 50 | grep -F '\"op\":\"QueryPathInfo\"' | grep -F '\"answered\":\"native\"'")
          machine.succeed("rm /run/vdaemon-proxy/forward-QueryPathInfo")

      with subtest("a live switch back out returns the socket to nix-daemon"):
          machine.succeed("${base}/bin/switch-to-configuration test")
          machine.fail("systemctl is-active vdaemon-proxy.socket")
          same(ask(), "direct answers differ after the switch out")
    '';
  }
