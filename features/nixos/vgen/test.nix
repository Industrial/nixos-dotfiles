# NixOS VM test for features/nixos/vgen (with features/nixos/vgc): pruning never removes
# the booted or the current generation, pinned generations survive vgc, and the boot menu
# matches the profile after a prune.
#
# The machine boots through systemd-boot on EFI (as nixpkgs' systemd-boot tests do), so
# the booted system is generation 1 and /boot holds a real menu. Four more generations
# are this system's specialisations (in its closure, so already in the VM's store), set
# with nix-env as nixos-rebuild would. A scratch profile of three small store paths shows
# the GC half: one pinned, one not, both unlinked by hand, then vgc runs.
#
#   nix build .#checks.x86_64-linux.vgen-vm
{pkgs}: let
  # Both features wrapped and switched on as drakkar has them, so vgc runs without its
  # --delete-older-than and vgen-prune is wanted by vgc.service.
  features = import ../../../lib/features.nix {inherit (pkgs) lib;};
in
  pkgs.testers.runNixOSTest {
    name = "vgen-vm";

    nodes.machine = {lib, ...}: {
      imports = [(features.feature ../vgc) (features.feature ./.)];
      features.nixos.vgc.enable = true;
      features.nixos.vgen.enable = true;

      virtualisation = {
        useBootLoader = true;
        useEFIBoot = true;
        cores = 2;
        memorySize = 2048;
      };
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      system.switch.enable = true;
      nix.enable = true;
      # A valid machine-id: systemd-boot's entries and dbus-broker want one.
      environment.etc."machine-id".text = "1234567890abcdef1234567890abcdef\n";

      # Generations 2..5: the same system with one file changed.
      specialisation = lib.genAttrs ["g2" "g3" "g4" "g5"] (name: {
        configuration.environment.etc."vgen-generation".text = name;
      });
    };

    testScript = ''
      import re

      P = "/nix/var/nix/profiles/system"
      S = "/nix/var/nix/profiles/scratch"

      def generations(profile):
          out = machine.succeed(f"ls {profile}-*-link -d")
          return sorted(int(l.rsplit("-", 2)[1]) for l in out.split())

      def menu():
          # Generations with an entry in the boot menu (specialisation entries count as
          # their generation's).
          out = machine.succeed("grep -h '^version Generation' /boot/loader/entries/*.conf")
          return sorted({int(l.split()[2]) for l in out.splitlines()})

      def default_entry_generation():
          entry = machine.succeed("sed -n 's/^default //p' /boot/loader/loader.conf").strip()
          line = machine.succeed(f"grep '^version Generation' /boot/loader/entries/{entry}")
          return int(line.split()[2])

      machine.wait_for_unit("multi-user.target")

      with subtest("five generations, the first one booted, all in the menu"):
          machine.succeed(f"test -e {P} || nix-env -p {P} --set /run/current-system")
          for name in ["g2", "g3", "g4", "g5"]:
              machine.succeed(f"nix-env -p {P} --set /run/current-system/specialisation/{name}")
          assert generations(P) == [1, 2, 3, 4, 5], generations(P)
          machine.succeed(f"{P}/bin/switch-to-configuration boot")
          assert menu() == [1, 2, 3, 4, 5], menu()
          assert default_entry_generation() == 5
          # Everything but the current generation is older than any retention.
          machine.succeed(f"touch -h -d '40 days ago' {P}-1-link {P}-2-link {P}-3-link {P}-4-link")

      with subtest("list marks the booted, current and pinned generations and diffs neighbours"):
          machine.succeed("vgen pin 3 --profile system")
          assert machine.succeed("readlink /nix/var/nix/gcroots/vgen/system-3-link") == machine.succeed(f"readlink {P}-3-link")
          listing = machine.succeed("vgen list --profile system")
          print(listing)
          lines = {int(l.split()[0]): l for l in listing.splitlines() if re.match(r"^\s+\d+\s", l)}
          assert "booted" in lines[1] and "running" in lines[1], lines[1]
          assert "pinned" in lines[3], lines[3]
          assert "current" in lines[5] and "boot default" in lines[5], lines[5]
          assert "vs 4:" in lines[5] and "changed" in lines[5], lines[5]

      with subtest("a dry run changes nothing"):
          out = machine.succeed("vgen prune --keep 1 --dry-run")
          assert "would remove generations 2 4 of /nix/var/nix/profiles/system" in out, out
          assert generations(P) == [1, 2, 3, 4, 5]
          assert menu() == [1, 2, 3, 4, 5]

      with subtest("pruning keeps the booted, current and pinned generations, and the menu follows"):
          out = machine.succeed("vgen prune --keep 1")
          print(out)
          assert "keeping generation 1 of /nix/var/nix/profiles/system: booted" in out, out
          assert "keeping generation 3 of /nix/var/nix/profiles/system: pinned" in out, out
          assert generations(P) == [1, 3, 5], generations(P)
          assert menu() == [1, 3, 5], menu()
          assert default_entry_generation() == 5
          machine.succeed("test -e /run/booted-system/init")

      with subtest("the boot menu's default stays, even when it is no profile's current"):
          # Boot generation 3 next, as `switch-to-configuration boot` from an older link does.
          machine.succeed(f"{P}-3-link/bin/switch-to-configuration boot")
          assert default_entry_generation() == 3
          machine.succeed("vgen unpin 3 --profile system")
          machine.fail("test -L /nix/var/nix/gcroots/vgen/system-3-link")
          listed = machine.succeed("vgen list --profile system --no-diff")
          assert any(l.split()[0] == "3" and "boot default" in l for l in listed.splitlines() if l.startswith("  ")), listed
          out = machine.succeed("vgen prune --keep 0")
          assert "keeping generation 3 of /nix/var/nix/profiles/system: boot default" in out, out
          assert generations(P) == [1, 3, 5], generations(P)
          assert menu() == [1, 3, 5], menu()
          assert default_entry_generation() == 3

      with subtest("once it is no longer the default, the generation goes; booted and current still stay"):
          machine.succeed(f"{P}/bin/switch-to-configuration boot")
          machine.succeed("vgen prune --keep 0")
          assert generations(P) == [1, 5], generations(P)
          assert menu() == [1, 5], menu()
          assert default_entry_generation() == 5

      with subtest("a pinned generation survives vgc; an unpinned one does not"):
          paths = []
          for name in ["kept", "dropped", "current"]:
              machine.succeed(f"echo {name} > /tmp/vgen-{name}")
              paths.append(machine.succeed(f"nix-store --add /tmp/vgen-{name}").strip())
              machine.succeed(f"nix-env -p {S} --set {paths[-1]}")
          kept, dropped, _ = paths
          machine.succeed(f"vgen pin 1 --profile {S}")
          # The links go by hand, as `nix-env --delete-generations` would take them.
          machine.succeed(f"nix-env -p {S} --delete-generations 1 2")
          dead = machine.succeed("vgc plan --print-dead")
          assert dropped in dead and kept not in dead, dead
          machine.succeed("systemctl start vgc.service")
          machine.succeed(f"test -e {kept}")
          machine.fail(f"test -e {dropped}")

      with subtest("vgc's run brought the prune in first"):
          prune_done = int(machine.succeed("systemctl show -P ExecMainExitTimestampMonotonic vgen-prune").strip())
          vgc_start = int(machine.succeed("systemctl show -P ExecMainStartTimestampMonotonic vgc").strip())
          assert 0 < prune_done <= vgc_start, (prune_done, vgc_start)
          machine.succeed("systemctl show -P Result vgen-prune | grep -qx success")
          assert generations(P) == [1, 5]
    '';
  }
