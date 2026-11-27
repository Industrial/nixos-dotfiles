# features/ai/agent-vm in a VM (ADR-0009, #353), with a real microVM nested inside it:
#
#   nix build .#checks.x86_64-linux.agent-vm
#
#   host      muninn's STIG test-host profile and the restricted daemon (allowed-users = @wheel).
#             It boots WITHOUT the feature; the `agentvm` specialisation adds it (two slots),
#             switched in live and out again. alice is the operator (group agent-vm, with an
#             ssh key in ~/.ssh), bob a user who is not. Its eth1 carries a LAN address
#             (192.168.1.1), a tailnet-like one (100.64.0.1) and a "public" one (203.0.113.1).
#   internet  203.0.113.10: the web, as the guest's proxy sees it. dnsmasq on .53 answers
#             github.com and evil.example with .10, and fleet-rebind.test (allowlisted) with
#             the fleet node's tailnet address; an http server serves a page and a git
#             repository (dumb http) at http://github.com/test/repo.git.
#   fleet     100.64.0.5 (tailnet-like) and 192.168.1.5 (LAN): a fleet host with a web server.
#
# Covered, from inside the guest (`agentvm-probe`, run as the guest's agent by alice's
# `vagent run --command`), the acceptance criteria of #353:
#   1. the operator's ~/.ssh is absent: no /home/alice, no file with alice's key in it, and a
#      store path the host has (and the guest's closure does not) is absent;
#   2. fleet hosts are unreachable: by address (no route) and through the proxy (refused by
#      name, and an allowlisted name that resolves to a tailnet address goes nowhere);
#   3. a host outside the allowlist is unreachable, by name and by address;
#   4. an allowlisted host works: the page, and the session's clone of the base ref;
#   5. writes land only in the worktree: markers written in /work, /work/home and /tmp; on
#      the host, the only ones are under the slot's work directory.
# And on the host: the session started as alice (not root) through polkit, bob is refused;
# the VMM and virtiofsd run as the slot's own user, which cannot read alice's home or the
# other slot; alice's Nix still works before, during and after; switched out, nothing is left.
{
  pkgs,
  inputs,
}: let
  keys = import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs;
  # A distinctive line of alice's private key: nothing in the guest may contain it.
  keyLine = builtins.elemAt (pkgs.lib.splitString "\n" keys.snakeOilEd25519PrivateKey.text) 1;
  # On the host's store (its /etc references it), not in any guest's closure.
  hostOnly = pkgs.writeText "agentvm-host-only" "only on the host\n";
  # Its path as plain text: a reference would pull it into the probe's, and so the guest's, closure.
  hostOnlyPath = builtins.unsafeDiscardStringContext "${hostOnly}";

  repo = pkgs.runCommand "agentvm-test-repo" {nativeBuildInputs = [pkgs.git];} ''
    export HOME=$TMPDIR
    git init -q -b main work
    echo hello > work/README
    git -C work add README
    git -C work -c user.name=t -c user.email=t@t commit -qm init
    mkdir -p $out/test
    git clone -q --bare work $out/test/repo.git
    git -C $out/test/repo.git update-server-info
    echo allowed > $out/index.html
  '';

  probe = pkgs.writeShellScriptBin "agentvm-probe" ''
    set -u
    fails=0
    check() { if "$@" >/dev/null 2>&1; then echo "PASS $*"; else echo "FAIL $*"; fails=$((fails + 1)); fi; }
    refuse() { if "$@" >/dev/null 2>&1; then echo "FAIL (reachable) $*"; fails=$((fails + 1)); else echo "PASS (refused) $*"; fi; }
    nokey() { ! grep -rqsF -- '${keyLine}' /work /etc /run /home /tmp /var /nix/.rw-store; }

    # 1. the operator's ssh key and the host's store are not here
    check test ! -e /home/alice
    check nokey
    check test ! -e ${hostOnlyPath}
    # 2. fleet hosts: no route, and the proxy refuses them
    refuse curl -sf -m 5 --noproxy '*' http://100.64.0.5/
    refuse curl -sf -m 5 --noproxy '*' http://192.168.1.5/
    refuse curl -sf -m 10 http://100.64.0.5/
    refuse curl -sf -m 10 http://fleet-rebind.test/
    check test -z "$(ip route show default)"
    # 3. outside the allowlist: by name through the proxy, by address without it
    refuse curl -sf -m 10 http://evil.example/
    refuse curl -sf -m 5 --noproxy '*' http://203.0.113.10/
    # 4. the allowlist works, and the session's clone is the base plus a new branch
    check sh -c 'curl -sf -m 10 http://github.com/ | grep -q allowed'
    check test -f /work/repo/README
    check test "$(git -C /work/repo rev-parse --abbrev-ref HEAD)" = probe
    # 5. writes: the share, the home on it, and the guest's own /tmp
    echo m > /work/repo/agentvm-marker-repo
    echo m > /work/home/agentvm-marker-home
    echo m > /tmp/agentvm-marker-tmp
    check test -f /tmp/agentvm-marker-tmp
    echo "probe: $fails failed"
    exit "$fails"
  '';

  base = {lib, ...}: {
    imports = [../../security/stig/profiles/test-host.nix];
    boot.loader.grub.enable = false;
    documentation.enable = false;
    system.stateVersion = "25.05";
    # As in the STIG VM harness: the profile requires timesyncd, the instrumentation disables it.
    services.timesyncd.enable = lib.mkForce true;
    nix.settings.allowed-users = ["@wheel"];
    system.switch.enable = true;
  };
in
  pkgs.testers.runNixOSTest {
    name = "agent-vm";
    node.specialArgs = {inherit inputs;};

    nodes = {
      host = {lib, ...}: {
        imports = [base];
        virtualisation = {
          memorySize = 4096;
          cores = 4;
          diskSize = 8192;
        };
        networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
          {
            address = "192.168.1.1";
            prefixLength = 24;
          }
          {
            address = "100.64.0.1";
            prefixLength = 24;
          }
          {
            address = "203.0.113.1";
            prefixLength = 24;
          }
        ];
        environment.etc."agentvm-host-only".source = hostOnly;

        users.users.alice = {
          isNormalUser = true;
          extraGroups = ["wheel"];
        };
        users.users.bob.isNormalUser = true;
        systemd.tmpfiles.rules = [
          "d /home/alice/.ssh 0700 alice users - -"
          "C /home/alice/.ssh/id_ed25519 0600 alice users - ${keys.snakeOilEd25519PrivateKey}"
          "Z /home/alice/.ssh 0700 alice users - -"
        ];

        specialisation.agentvm.configuration = {
          imports = [./default.nix];
          features.ai.agent-vm = {
            slots = 2;
            memory = 1024;
            vcpu = 2;
            volumeSize = 2048;
            operators = ["alice"];
            resolvers = ["203.0.113.53"];
            allowlist = ["^github\\.com$" "^fleet-rebind\\.test$"];
            guestPackages = [pkgs.git pkgs.curl pkgs.iproute2 probe];
          };
        };
      };

      internet = {lib, ...}: {
        networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
          {
            address = "203.0.113.10";
            prefixLength = 24;
          }
          {
            address = "203.0.113.53";
            prefixLength = 24;
          }
        ];
        networking.firewall.enable = false;
        services.dnsmasq = {
          enable = true;
          resolveLocalQueries = false;
          settings = {
            listen-address = "203.0.113.53";
            bind-interfaces = true;
            no-resolv = true;
            address = ["/github.com/203.0.113.10" "/evil.example/203.0.113.10" "/fleet-rebind.test/100.64.0.5"];
          };
        };
        systemd.services.web = {
          wantedBy = ["multi-user.target"];
          serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 -m http.server 80 --bind 203.0.113.10 --directory ${repo}";
        };
      };

      fleet = {lib, ...}: {
        networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
          {
            address = "100.64.0.5";
            prefixLength = 24;
          }
          {
            address = "192.168.1.5";
            prefixLength = 24;
          }
        ];
        networking.firewall.enable = false;
        systemd.services.web = {
          wantedBy = ["multi-user.target"];
          serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 -m http.server 80 --directory /etc";
        };
      };
    };

    testScript = ''
      start_all()
      internet.wait_for_unit("dnsmasq.service")
      internet.wait_for_open_port(80, "203.0.113.10")
      fleet.wait_for_open_port(80)
      host.wait_for_unit("multi-user.target")

      def nix_as(user):
          host.succeed(f"runuser -u {user} -- nix-store -q --hash /run/current-system")

      with subtest("without the feature: no slots, alice's Nix works"):
          host.fail("systemctl cat microvm-agent-1.service")
          host.fail("id agent-vm-1")
          nix_as("alice")
          # the host itself reaches the fleet and the web: the guest's failures below are its own
          host.succeed("curl -sf -m 5 http://100.64.0.5/ >/dev/null")
          host.succeed("curl -sf -m 5 http://203.0.113.10/ | grep allowed")

      with subtest("switched in live"):
          host.succeed("/run/current-system/specialisation/agentvm/bin/switch-to-configuration test")
          host.succeed("id agent-vm-1 && id agent-vm-2")
          host.succeed("id -nG alice | grep -w agent-vm")
          host.succeed("stat -c '%U:%G %a' /var/lib/microvm-host/agent-1 | grep -x 'agent-vm-1:agent-vm 2770'")
          nix_as("alice")

      with subtest("bob may not start a slot; alice may"):
          host.fail("runuser -u bob -- systemctl start microvm-agent-1.service")
          host.succeed("runuser -u alice -- systemctl start microvm-agent-1.service")
          # The VMM (named microvm@agent-1 by microvm.nix) and virtiofsd: the slot's user, not root.
          for unit in ["microvm-agent-1", "microvm-agent-1-fs-work"]:
              host.succeed(f"ps -o user= -p $(systemctl show -p MainPID --value {unit}.service) | grep -x agent-vm-1")
          host.fail("ps -eo user=,args= | grep -E '^root +[^ ]*(cloud-hypervisor|microvm@|virtiofsd)'")
          # the vsock socket: the operators' group may connect, nobody else
          host.succeed("stat -c '%a %U:%G' /var/lib/microvm-host/agent-1/notify.vsock | grep -x '660 agent-vm-1:agent-vm'")
          # the slot's own user: not alice's home, not the other slot
          host.fail("runuser -u agent-vm-1 -- cat /home/alice/.ssh/id_ed25519")
          host.fail("runuser -u agent-vm-1 -- ls /var/lib/microvm-host/agent-2")
          nix_as("alice")
          host.succeed("runuser -u alice -- systemctl stop microvm-agent-1.service")

      with subtest("a session as alice: the probe inside the guest"):
          out = host.succeed(
              "runuser -u alice -- vagent run --slot 1 --branch probe"
              " --repo http://github.com/test/repo.git --command agentvm-probe 2>&1"
          )
          print(out)
          assert "probe: 0 failed" in out, out
          assert "ready in" in out, out
          # torn down: the VM stopped, the key gone
          host.fail("systemctl is-active microvm-agent-1.service")
          host.fail("ls /tmp/vagent/s1-*/key")

      with subtest("writes landed only in the worktree"):
          found = host.succeed("find / -xdev -name 'agentvm-marker-*' 2>/dev/null | sort").split()
          print(found)
          assert found == [
              "/var/lib/microvm-host/agent-1/work/home/agentvm-marker-home",
              "/var/lib/microvm-host/agent-1/work/repo/agentvm-marker-repo",
          ], found
          host.succeed("stat -c %U /var/lib/microvm-host/agent-1/work/repo/agentvm-marker-repo | grep -x agent-vm-1")

      with subtest("switched out live: nothing left, alice's Nix works"):
          host.succeed("/run/booted-system/bin/switch-to-configuration test")
          host.fail("systemctl cat microvm-agent-1.service")
          host.fail("ip link show agvm1")
          host.fail("id agent-vm-1")
          nix_as("alice")
    '';
  }
