# vlocate (GH-245) in a VM, as a normal user, in all three shells:
#
#   nix build .#checks.x86_64-linux.vlocate-vm
#
# The machine's own system carries cowsay without putting it on PATH
# (system.extraDependencies), and /var/lib/vci/roots/main-mimir stands for another fleet
# host's latest build (vci's roots on the cache host), also with cowsay. There is no
# nix-locate database offline: the nixpkgs half is the crate's tests'.
#
# Covered, as alice:
#   1. `vlocate cowsay` finds it in this host's system and mimir's; nothing for a name no
#      system has, with exit 1; a path-like name is refused;
#   2. fish and zsh: a missing command prints vlocate's hint and exits 127; a command no
#      system has gets the plain message, still 127;
#   3. nushell: the autoload file's hook returns the hint (and null when there is none);
#   4. the lookup is quick enough for an interactive shell (timed, printed as TIMING).
{pkgs}: let
  inherit (pkgs) lib;
in
  pkgs.testers.runNixOSTest {
    name = "vlocate-vm";

    nodes.machine = {config, ...}: {
      imports = [./default.nix];
      # features/cli/shell-init declares this; the test has no shell-init, so declare it.
      options.cli.shellInit.extraAutoload = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = {};
      };
      config = {
        programs.fish.enable = true;
        programs.zsh.enable = true;
        environment.systemPackages = [pkgs.nushell];
        environment.etc."vlocate-test/vlocate.nu".source = config.cli.shellInit.extraAutoload."60-vlocate.nu";
        # Calls the hook as nushell does, printing its value as JSON (a string, or null).
        environment.etc."vlocate-test/check.nu".text = ''
          source /etc/vlocate-test/vlocate.nu
          def main [cmd: string] { do $env.config.hooks.command_not_found $cmd | to json }
        '';
        system.extraDependencies = [pkgs.cowsay];
        systemd.tmpfiles.rules = [
          "d /var/lib/vci/roots 0755 root root - -"
          "L+ /var/lib/vci/roots/main-mimir - - - - ${pkgs.cowsay}"
        ];
        users.users.alice = {
          isNormalUser = true;
          uid = 1000;
        };
        virtualisation.memorySize = 1024;
      };
    };

    testScript = ''
      import json
      import time

      def alice(cmd):
          return "su - alice -c " + repr(cmd)

      machine.wait_for_unit("multi-user.target")
      machine.fail(alice("command -v cowsay"))

      with subtest("vlocate finds it in this host's system and in mimir's"):
          start = time.monotonic()
          out = machine.succeed(alice("vlocate cowsay"))
          took = time.monotonic() - start
          print(f"TIMING vlocate cowsay: {took:.2f}s (including su)")
          t.assertIn("cowsay-", out)
          t.assertIn("this host, mimir", out)
          t.assertIn("/bin/cowsay", out)
          status, _ = machine.execute(alice("vlocate no-such-command-anywhere"))
          t.assertEqual(status, 1)
          status, _ = machine.execute(alice("vlocate ../etc/passwd"))
          t.assertEqual(status, 1)

      with subtest("fish: a missing command gets vlocate's hint, exit 127"):
          status, out = machine.execute(alice("fish -i -c cowsay 2>&1"))
          t.assertEqual(status, 127, out)
          t.assertIn("cowsay: command not found.", out)
          t.assertIn("In the fleet's systems:", out)
          status, out = machine.execute(alice("fish -i -c no-such-command-anywhere 2>&1"))
          t.assertEqual(status, 127, out)
          t.assertIn("no-such-command-anywhere: command not found", out)
          t.assertNotIn("In the fleet's systems", out)

      with subtest("zsh: a missing command gets vlocate's hint, exit 127"):
          status, out = machine.execute(alice("zsh -i -c cowsay 2>&1"))
          t.assertEqual(status, 127, out)
          t.assertIn("cowsay: command not found.", out)
          t.assertIn("mimir", out)

      with subtest("nushell: the autoload hook returns the hint, and nothing when there is none"):
          hint = json.loads(machine.succeed(alice("nu /etc/vlocate-test/check.nu cowsay")))
          t.assertIn("cowsay: command not found.", hint)
          t.assertIn("this host, mimir", hint)
          none = json.loads(machine.succeed(alice("nu /etc/vlocate-test/check.nu no-such-command-anywhere")))
          t.assertIsNone(none)
    '';
  }
