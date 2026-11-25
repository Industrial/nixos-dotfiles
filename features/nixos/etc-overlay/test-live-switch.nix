# NixOS VM test for features/nixos/etc-overlay (GH-185), the gate, once per fleet host: the
# host's own config (./node.nix, `hostname`) boots WITHOUT the feature, with state planted
# the way that host has it, then
#
#   1. switches LIVE into the feature (switch-to-configuration, no reboot),
#   2. changes state under the overlay (a new NM connection, a deleted file),
#   3. switches LIVE out again (the rollback: the feature off),
#   4. boots cold INTO the feature (the overlay generation's own VM, on the same disk:
#      the first boot after `switch-to-configuration boot`), changes state again,
#   5. boots cold OUT of it (back to the generation without the feature),
#
# and after every step asserts:
#   - the followed state is unchanged: the machine-id, every ssh host key the host's
#     services.openssh.hostKeys names, its NetworkManager connections (when NM is on), the
#     planted files with their content, mode and owner, and the user's shadow and passwd
#     lines, under whichever user database the host runs (userborn or
#     update-users-groups.pl);
#   - nothing else stateful was lost or changed either: every file of /etc that the
#     generation does not declare (the set carry-in works on, found in the VM, not listed
#     here), compared before and after each step;
#   - the user's password is accepted and a wrong one refused; polkit and accounts-daemon
#     (when the host runs them) are up with no 217/USER since the step; no unit failed
#     beyond the VM baseline;
#   - when the host runs auditd with watches on /etc (mimir's STIG identity rules), a write
#     to a watched file is still audited;
#   - when the host runs vhealth, `vhealth check` as the vhealth user lost no probe.
#
# What the test follows is read off the host's evaluated config (`facts` below), so a host
# that turns NM, userborn, auditd or vhealth on or off changes its own gate.
#
# Two evaluations of the host: the node, and the node extended with the feature on
# (extendModules), whose toplevel is the live switch target and whose VM is the cold boot.
#
#   nix build .#checks.x86_64-linux.etc-overlay-live-switch          # drakkar
#   nix build .#checks.x86_64-linux.etc-overlay-live-switch-<host>   # mimir, huginn, muninn
{
  pkgs,
  inputs,
  hostname ? "drakkar",
}: let
  inherit (inputs.nixpkgs) lib;
  host = import ./node.nix {inherit inputs hostname;};
  user = host.settings.username;
in
  pkgs.testers.runNixOSTest {
    name =
      if hostname == "drakkar"
      then "etc-overlay-live-switch"
      else "etc-overlay-live-switch-${hostname}";
    inherit (host) node;

    nodes.machine = {
      config,
      extendModules,
      ...
    }: {
      imports = [host.module];
      options.gh185 = {
        withOverlay = lib.mkOption {
          type = lib.types.raw;
          description = "This node with features.nixos.etc-overlay on.";
        };
        isOverlayVariant = lib.mkEnableOption "the extension of the node with the feature on";
        facts = lib.mkOption {
          type = lib.types.raw;
          readOnly = true;
          description = "What the gate follows on this host, read off its config.";
        };
      };
      config = {
        # A test node only gets switch-to-configuration with specialisations
        # (nixos/lib/testing/nixos-test-base.nix); this one switches without any.
        system.switch.enable = true;
        gh185.withOverlay = extendModules {
          modules = [
            {
              # Over the node's mkOverride 60 false (node.nix).
              features.nixos.etc-overlay.enable = lib.mkForce true;
              gh185.isOverlayVariant = true;
            }
          ];
        };
        gh185.facts = {
          # Relative to /etc: the keys sshd generates there on first start.
          sshKeys =
            lib.optionals config.services.openssh.enable
            (map (k: lib.removePrefix "/etc/" k.path)
              (lib.filter (k: lib.hasPrefix "/etc/" k.path) config.services.openssh.hostKeys));
          networkmanager = config.networking.networkmanager.enable;
          userDb =
            if config.services.userborn.enable
            then "userborn"
            else if config.systemd.sysusers.enable
            then "sysusers"
            else "update-users-groups.pl";
          # A password set at runtime survives only a mutable user database.
          setsPassword = config.users.mutableUsers;
          # timedatectl set-timezone writes the /etc/localtime link when time.timeZone is
          # unset (drakkar); a declared one is the generation's, not state.
          localtime = !(config.environment.etc ? localtime);
          # wpa_supplicant's imperative.conf, owned by its own user where it has one.
          wpaOwner =
            if config.users.users ? wpa_supplicant
            then "wpa_supplicant:wpa_supplicant"
            else "nobody:nogroup";
          units = lib.optional config.security.polkit.enable "polkit.service" ++ lib.optional config.services.accounts-daemon.enable "accounts-daemon.service";
          # The watches `-w /etc/<path> -p …w…` of the host's audit rules.
          auditWatches = lib.optionals config.security.auditd.enable (lib.concatMap (r: let
            m = builtins.match "-w (/etc/[^ ]+) -p [a-z]*w[a-z]*( .*)?" r;
          in
            lib.optional (m != null) (builtins.head m))
          config.security.audit.rules);
          vhealth = config.features.nix.vhealth.enable;
          # Units that need the tailnet or the fleet, which a VM has not got.
          offline = lib.optional config.features.nix.vcache.enable "vcache.service" ++ lib.optional config.features.fleet.comin.enable "comin.service";
        };
        # The test script's string context is dropped, so the overlay generation (the live
        # switch target) and its VM (the cold boot) reach the VM's store this way. Only from
        # the node itself, or the extension would depend on its own extension.
        system.extraDependencies = lib.optional (!config.gh185.isOverlayVariant) config.gh185.withOverlay.config.system.build.vm;
      };
    };

    testScript = {nodes, ...}: let
      base = nodes.machine;
      overlay = base.gh185.withOverlay.config;
      inherit (base.gh185) facts;
      py = builtins.toJSON;

      # Every piece of state the test follows by name, one line each, compared as a whole.
      state = pkgs.writeShellScript "gh185-state" ''
        cd /etc
        echo "machine-id $(cat machine-id)"
        for k in ${lib.escapeShellArgs (map (k: "${k}.pub") facts.sshKeys)}; do
          echo "$k $(ssh-keygen -lf "$k" | cut -d' ' -f2)"
        done
        for f in adjtime localtime security/opasswd wpa_supplicant/imperative.conf mullvad-vpn/*.json NetworkManager/system-connections/*; do
          if [ -L "$f" ]; then echo "$f -> $(readlink "$f")"; continue; fi
          [ -e "$f" ] && echo "$f $(stat -c '%a %U:%G' "$f") $(sha256sum < "$f" | cut -c1-16)"
        done
        echo "shadow $(grep '^${user}:' shadow | cut -d: -f1-2)"
        echo "passwd $(grep '^${user}:' passwd)"
      '';

      # Every stateful file of /etc, found rather than listed: a regular file or symlink the
      # running generation does not declare (not in its /etc tree, not a link into
      # /etc/static), the set carry-in and carry-out work on. Left out: what is rewritten on
      # every activation or boot (NIXOS, .updated, resolv.conf, the shadow-utils backups
      # and lock), whose content says nothing about a carry.
      inventory = pkgs.writeShellScript "gh185-inventory" ''
        declared=$(readlink -f /run/current-system/etc)
        cd /etc
        find . -xdev -mindepth 1 \( -type f -o -type l \) -printf '%P\0' | sort -z | while IFS= read -r -d "" p; do
          case "$p" in
            .clean | static | NIXOS | .updated | .pwd.lock | resolv.conf | resolv.conf.bak | *-) continue ;;
          esac
          if [ -L "$p" ]; then
            case "$(readlink "$p")" in /etc/static/*) continue ;; esac
          fi
          if [ -e "$declared/$p" ] || [ -L "$declared/$p" ]; then continue; fi
          if [ -L "$p" ]; then
            echo "$p -> $(readlink "$p")"
          else
            echo "$p $(stat -c '%a %U:%G' "$p") $(sha256sum < "$p" | cut -c1-16)"
          fi
        done
      '';

      # Leftovers any host can hold (measured on drakkar and mimir, read-only: adjtime,
      # security/opasswd, wpa_supplicant/imperative.conf, mullvad-vpn/*), plus the
      # localtime link where the host leaves the timezone to timedatectl.
      plant = pkgs.writeShellScript "gh185-plant" ''
        set -e
        cd /etc
        printf '0.000000 1795300000 0.000000\n1795300000\nUTC\n' > adjtime
        mkdir -p security wpa_supplicant mullvad-vpn
        printf '${user}:1000:1:$y$j9T$gh185$old\n' > security/opasswd
        chmod 600 security/opasswd
        printf 'network={\n  ssid="gh185"\n}\n' > wpa_supplicant/imperative.conf
        chmod 664 wpa_supplicant/imperative.conf
        chown ${facts.wpaOwner} wpa_supplicant/imperative.conf
        printf '{"gh185":"settings"}\n' > mullvad-vpn/settings.json
        printf '{"gh185":"device"}\n' > mullvad-vpn/device.json
        printf '{"gh185":"history"}\n' > mullvad-vpn/account-history.json
        chmod 600 mullvad-vpn/device.json mullvad-vpn/account-history.json
        ${lib.optionalString facts.localtime "ln -sfn ${pkgs.tzdata}/share/zoneinfo/Europe/Amsterdam localtime"}
        ${lib.optionalString facts.setsPassword "echo '${user}:gh185-pw' | chpasswd"}
      '';

      password = pkgs.writeShellScript "gh185-password" ''
        printf '%s\0' "$1" | /run/wrappers/bin/unix_chkpwd ${user} nonull
      '';
    in ''
      import json
      import time

      HOST = ${py hostname}
      USER = ${py user}
      FACTS = json.loads(${py (py facts)})
      print(f"GH185 [{HOST}] facts: {FACTS}")
      overlay_system = "${overlay.system.build.toplevel}"
      overlay_vm = "${overlay.system.build.vm}/bin/run-${overlay.networking.hostName}-vm"
      ausearch = "${pkgs.audit}/bin/ausearch"

      def cursor(m):
          return m.succeed("journalctl -n0 --show-cursor --no-pager | sed -n 's/^-- cursor: //p'").strip()

      def etc_fstype(m):
          return m.succeed("findmnt -n -o FSTYPE --mountpoint /etc || echo plain").strip()

      def vhealth(m):
          deadline = time.monotonic() + 90
          while True:
              _, out = m.execute("runuser -u vhealth -- /run/current-system/sw/bin/vhealth check --json")
              try:
                  r = json.loads(out.strip().splitlines()[-1])
                  return r["healthy"], {p["name"]: p["up"] for p in r["probes"]}
              except Exception:
                  if time.monotonic() > deadline:
                      raise Exception(f"vhealth check gave no report:\n{out}")
                  time.sleep(3)

      def audited(m, label):
          # A write to a watched file (an attribute change: chmod to its own mode) must reach
          # the audit log. After a live switch the kernel's watch may still be on the hidden
          # /etc; this is what would show it. The shell execs chmod, so the record carries the
          # pid it printed: this write's record, not an earlier one.
          if not FACTS["auditWatches"]:
              return
          path = "/etc/passwd" if "/etc/passwd" in FACTS["auditWatches"] else FACTS["auditWatches"][0]
          mode = m.succeed(f"stat -c %a {path}").strip()
          pid = m.succeed(f"sh -c 'echo $$; exec chmod {mode} {path}'").strip()
          m.wait_until_succeeds(f"{ausearch} --input-logs -ts boot -p {pid} -f {path} >/dev/null 2>&1", timeout=60)
          print(f"GH185 [{label}] audited: chmod of {path} logged (pid {pid})")

      def healthy(m, label, since, vh_base):
          if FACTS["units"]:
              units = " ".join(FACTS["units"])
              m.succeed(f"systemctl start {units}")
              m.succeed(f"systemctl is-active {units}")
          window = f"--after-cursor='{since}'" if since else "-b"
          bad = m.succeed(f"journalctl --no-pager -o cat {window} | grep -c 'status=217/USER' || true").strip()
          failed = set(m.succeed("systemctl --failed --no-legend --plain | cut -d' ' -f1").split())
          assert failed <= allowed_failed, f"[{label}] failed units: {sorted(failed - allowed_failed)}"
          assert bad == "0", f"[{label}] {bad} unit(s) exited 217/USER"
          m.succeed(f"su - {USER} -c true")
          if FACTS["setsPassword"]:
              m.succeed(f"runuser -u {USER} -- ${password} gh185-pw")
              m.fail(f"runuser -u {USER} -- ${password} wrong-password")
          audited(m, label)
          if not FACTS["vhealth"]:
              return
          # Probes settle after a switch: wait for every probe that was up to be up again.
          deadline = time.monotonic() + 120
          while True:
              ok, probes = vhealth(m)
              lost = sorted(n for n, up in vh_base.items() if up and not probes.get(n, False))
              if not lost:
                  break
              if time.monotonic() > deadline:
                  raise Exception(f"[{label}] vhealth probes down that were up: {lost}")
              time.sleep(5)
          print(f"GH185 [{label}] vhealth healthy={ok} probes={probes}")

      def same_state(m, label, expected):
          now = m.succeed("${state}")
          print(f"GH185 [{label}] state:\n{now}")
          assert now == expected, f"[{label}] state changed:\nexpected:\n{expected}\nnow:\n{now}"

      def inventory(m):
          lines = m.succeed("${inventory}").splitlines()
          return dict(l.split(" ", 1) for l in lines)

      def same_inventory(m, label, before):
          now = inventory(m)
          lost = sorted(p for p in before if p not in now)
          changed = sorted(f"{p}: {before[p]} -> {now[p]}" for p in before if p in now and now[p] != before[p])
          new = sorted(p for p in now if p not in before)
          print(f"GH185 [{label}] inventory: {len(before)} before, {len(now)} now, new: {new}")
          assert not lost and not changed, f"[{label}] stateful /etc lost: {lost}, changed: {changed}"

      def switch(target, label):
          rc, out = machine.execute(f"{target}/bin/switch-to-configuration test 2>&1")
          print(f"GH185 [{label}] switch rc={rc}\n{out[-4000:]}")
          # rc 4 is a unit that failed to (re)start; vcache has no tailnet in a VM. healthy()
          # checks the failed units against the baseline.
          assert "FAILED to carry" not in out, out

      def add_connection(m, ifname, name):
          if not FACTS["networkmanager"]:
              return
          m.succeed(f"nmcli connection add type ethernet ifname {ifname} con-name '{name}'")
          m.wait_for_file(f"'/etc/NetworkManager/system-connections/{name}.nmconnection'")

      machine.wait_for_unit("multi-user.target")
      base_system = machine.succeed("readlink -f /run/current-system").strip()

      with subtest(f"boot {HOST} without the feature, plant its state"):
          assert etc_fstype(machine) == "plain"
          if FACTS["networkmanager"]:
              machine.wait_for_unit("NetworkManager.service")
          for k in FACTS["sshKeys"]:
              machine.wait_for_file(f"/etc/{k}.pub")
          if FACTS["auditWatches"]:
              machine.wait_for_unit("auditd.service")
          machine.succeed("${plant}")
          add_connection(machine, "gh185", "Wired connection 1")
          planted = machine.succeed("${state}")
          print(f"GH185 planted:\n{planted}")
          vh_base = vhealth(machine)[1] if FACTS["vhealth"] else {}
          print(f"GH185 vhealth baseline: {vh_base}")
          # What already fails here without the feature, and what cannot work in a VM.
          allowed_failed = set(machine.succeed("systemctl --failed --no-legend --plain | cut -d' ' -f1").split()) | set(FACTS["offline"])
          print(f"GH185 failed at baseline: {sorted(allowed_failed)}")
          print(f"GH185 stateful /etc at baseline: {sorted(inventory(machine).items())}")
          audited(machine, "baseline")

      with subtest("live switch INTO the overlay keeps the state"):
          since = cursor(machine)
          inv = inventory(machine)
          switch(overlay_system, "live in")
          assert etc_fstype(machine) == "overlay"
          same_state(machine, "live in", planted)
          same_inventory(machine, "live in", inv)
          healthy(machine, "live in", since, vh_base)
          machine.succeed("test -e /.rw-etc/.seeded")
          # setup-etc.pl's link to its generation's tree is not carried: the overlay mounts
          # the tree itself and has no /etc/static, so a carried one would be stale.
          machine.fail("test -e /etc/static || test -L /etc/static")

      with subtest("change state under the overlay"):
          add_connection(machine, "gh185b", "gh185-overlay")
          machine.succeed("rm /etc/mullvad-vpn/account-history.json")
          changed = machine.succeed("${state}")
          assert "account-history" not in changed, changed
          assert "gh185-overlay.nmconnection" in changed or not FACTS["networkmanager"], changed

      with subtest("live switch OUT of the overlay keeps the state"):
          since = cursor(machine)
          inv = inventory(machine)
          switch(base_system, "live out")
          assert etc_fstype(machine) == "plain"
          same_state(machine, "live out", changed)
          same_inventory(machine, "live out", inv)
          healthy(machine, "live out", since, vh_base)
          machine.succeed("test -e /.rw-etc/.exited")

      with subtest("cold boot INTO the overlay keeps the state"):
          inv = inventory(machine)
          machine.shutdown()
          # The driver does not track a machine from create_machine: on a failure here it
          # would keep running and hold the build open, so it is killed on the way out.
          cold = create_machine(overlay_vm, name="machine", keep_machine_state=True)
          try:
              cold.start()
              cold.wait_for_unit("multi-user.target")
              assert etc_fstype(cold) == "overlay"
              print(cold.succeed("journalctl -b -o cat --no-pager | grep 'etc-overlay:' || true"))
              cold.succeed("ls -d /.rw-etc.stale-*")
              same_state(cold, "cold in", changed)
              same_inventory(cold, "cold in", inv)
              healthy(cold, "cold in", "", vh_base)
              add_connection(cold, "gh185c", "gh185-cold")
              cold.succeed("rm /etc/mullvad-vpn/device.json")
              changed_cold = cold.succeed("${state}")
              inv = inventory(cold)
              cold.shutdown()
          except BaseException:
              cold.crash()
              raise

      with subtest("cold boot OUT of the overlay keeps the state"):
          machine.start()
          machine.wait_for_unit("multi-user.target")
          assert etc_fstype(machine) == "plain"
          same_state(machine, "cold out", changed_cold)
          same_inventory(machine, "cold out", inv)
          healthy(machine, "cold out", "", vh_base)
          machine.succeed("test -e /.rw-etc/.exited")
    '';
  }
