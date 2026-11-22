# NixOS VM test for features/nixos/vfiles (rust/tools/vfiles via lib/vfiles.nix).
#
# The machine boots without the "extra" feature's files; a specialisation adds them.
# Switching between the two (switch-to-configuration test) runs the activation, and so
# vfiles, each time:
#
#   - adding the feature places its files; removing it removes them again;
#   - a real file already at a declared path is adopted: moved to .backup, then linked;
#   - a copied file edited by hand is reported as drift and never overwritten;
#   - a link whose out-of-store source (a checkout) is missing uses its fallback, and
#     moves to the source once it exists.
#
# A second machine, `fresh`, boots under userborn for the first time (GH-205): the
# activation runs before userborn.service has written alice, so the vfiles step defers,
# and vfiles.service places her files once userborn has.
#
#   nix build .#checks.x86_64-linux.vfiles-vm
{pkgs}: let
  home = "/home/alice";
  checkout = "${home}/checkout";
  # Every file in this test belongs to alice.
  alice = builtins.mapAttrs (_: f: f // {user = "alice";});
  extra = {
    vfiles.files = alice {
      "${home}/.config/extra/extra.toml" = {text = "extra = true\n";};
      "${home}/.config/adopted.conf" = {text = "declared\n";};
    };
  };
in
  pkgs.testers.runNixOSTest {
    name = "vfiles-vm";

    nodes.machine = {...}: {
      imports = [./default.nix];

      users.users.alice = {
        isNormalUser = true;
        group = "users";
      };

      vfiles.files = alice {
        "${home}/.config/base/linked.conf" = {text = "linked\n";};
        "${home}/.config/base/copied.conf" = {
          text = "copied\n";
          mode = "copy";
        };
        "${home}/.config/hypr/hyprland.lua" = {
          source = "${checkout}/hyprland.lua";
          fallback = pkgs.writeText "hyprland-fallback.lua" "-- fallback\n";
        };
      };
      specialisation.extra.configuration = extra;

      virtualisation.memorySize = 1024;
    };

    nodes.fresh = {...}: {
      imports = [./default.nix];

      services.userborn.enable = true;
      users.users.alice = {
        isNormalUser = true;
        group = "users";
      };

      vfiles.files = alice {
        "${home}/.config/base/linked.conf" = {text = "linked\n";};
      };

      virtualisation.memorySize = 1024;
    };

    testScript = ''
      import json

      def report():
          return json.loads(machine.succeed("cat /var/lib/vfiles/report.json"))

      def paths(group):
          return [e if isinstance(e, str) else e["path"] for e in report()[group]]

      def switch(to):
          machine.succeed(f"{to}/bin/switch-to-configuration test")

      base = "/run/booted-system"
      extra = f"{base}/specialisation/extra"

      machine.wait_for_unit("multi-user.target")

      with subtest("boot placed the declared files, owned by alice"):
          machine.succeed("test -L ${home}/.config/base/linked.conf")
          machine.succeed("grep -qx linked ${home}/.config/base/linked.conf")
          machine.succeed("test -f ${home}/.config/base/copied.conf -a ! -L ${home}/.config/base/copied.conf")
          machine.succeed("test \"$(stat -c %U ${home}/.config/base)\" = alice")
          machine.succeed("test \"$(stat -c %U ${home}/.config/base/copied.conf)\" = alice")
          manifest = json.loads(machine.succeed("cat /var/lib/vfiles/manifest.json"))
          assert len(manifest["files"]) == 3, manifest

      with subtest("a missing checkout falls back"):
          target = machine.succeed("readlink ${home}/.config/hypr/hyprland.lua").strip()
          assert target.endswith("hyprland-fallback.lua"), target

      with subtest("adding a feature places its files, adopting a real file with a backup"):
          machine.succeed("install -d -o alice -g users ${home}/.config")
          machine.succeed("echo handwritten > ${home}/.config/adopted.conf")
          switch(extra)
          machine.succeed("grep -qx 'extra = true' ${home}/.config/extra/extra.toml")
          machine.succeed("test -L ${home}/.config/adopted.conf")
          machine.succeed("grep -qx declared ${home}/.config/adopted.conf")
          machine.succeed("grep -qx handwritten ${home}/.config/adopted.conf.backup")
          assert "${home}/.config/adopted.conf" in paths("adopted"), report()

      with subtest("removing the feature removes its files; the backup stays"):
          switch(base)
          machine.fail("test -e ${home}/.config/extra/extra.toml")
          machine.fail("test -e ${home}/.config/adopted.conf")
          machine.succeed("grep -qx handwritten ${home}/.config/adopted.conf.backup")
          assert "${home}/.config/extra/extra.toml" in paths("removed"), report()

      with subtest("a hand-edited file is reported, not overwritten"):
          machine.succeed("echo 'my own edit' > ${home}/.config/base/copied.conf")
          switch(extra)
          machine.succeed("grep -qx 'my own edit' ${home}/.config/base/copied.conf")
          assert "${home}/.config/base/copied.conf" in paths("drift"), report()
          out = machine.succeed("vfiles --dry-run --spec /etc/vfiles/spec.json 2>&1")
          assert "drift: ${home}/.config/base/copied.conf" in out, out

      with subtest("the checkout, once there, replaces the fallback"):
          machine.succeed("install -d -o alice -g users ${checkout}")
          machine.succeed("echo '-- checkout' > ${checkout}/hyprland.lua")
          switch(base)
          target = machine.succeed("readlink ${home}/.config/hypr/hyprland.lua").strip()
          assert target == "${checkout}/hyprland.lua", target

      with subtest("nothing failed along the way"):
          assert report()["failed"] == [], report()

      with subtest("a fresh userborn boot defers to vfiles.service, which places the files (GH-205)"):
          fresh.wait_for_unit("vfiles.service")
          fresh.succeed("test -L ${home}/.config/base/linked.conf")
          fresh.succeed("grep -qx linked ${home}/.config/base/linked.conf")
          fresh.succeed("test \"$(stat -c %U ${home}/.config/base)\" = alice")
          # The unit placed the file, so the activation step before it had deferred.
          journal = fresh.succeed("journalctl -b -u vfiles.service")
          assert "1 placed" in journal, journal
          assert json.loads(fresh.succeed("cat /var/lib/vfiles/report.json"))["failed"] == []
    '';
  }
