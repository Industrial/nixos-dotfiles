# NixOS VM test for features/nix/vpush: a builder's builds reach the cache host's store
# through the post-build-hook and the spool daemon, and a fresh store then substitutes
# the whole closure from vcache.
#
#   builder  features/nix/vpush, pushing over ssh as `tom` (trusted on the cache, as the
#            operator is on drakkar) with a test key.
#   cache    features/nix/vcache serving its store, sshd, `tom` in trusted-users.
#   client   a fresh store (/tmp/fresh) that substitutes from vcache only, with
#            max-jobs 0: a path it cannot substitute fails the test instead of building.
#
# The built derivation references ruby and nodejs-slim (in the builder's store, not the
# cache's; python3 is in every test VM, for the driver), so the pushed closure is
# mid-size and mostly missing on the cache. Subtests:
#   1. a build is pushed; the client substitutes all of its closure from vcache (100%);
#   2. the cache's sshd is down during a build: the build succeeds, the item stays in the
#      spool, and it drains once sshd is back;
#   3. baseline: `nix copy --to ssh-ng://` against `vpush daemon --once` of the same
#      closure into the same empty cache, wall time and bytes sent (printed as BASELINE).
#
#   nix build .#checks.x86_64-linux.vpush-vm
{pkgs}: let
  keys = import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs;
  inherit (pkgs) lib;

  settingsFor = hostname: {
    inherit hostname;
    username = "tom";
    userdir = "/home/tom";
    system = "x86_64-linux";
    stateVersion = "24.11";
  };

  # A build that needs only bash and references ruby and nodejs: `nix-build drv.nix --argstr tag x`.
  drv = pkgs.writeText "vpush-test-drv.nix" ''
    {tag}: let
      bash = builtins.storePath "${pkgs.bash}";
      rb = builtins.storePath "${pkgs.ruby}";
      js = builtins.storePath "${pkgs.nodejs-slim}";
    in
      derivation {
        name = "vpush-test-''${tag}";
        system = builtins.currentSystem;
        builder = "''${bash}/bin/bash";
        args = ["-c" "echo ''${rb} ''${js} ''${tag} > $out"];
      }
  '';

  sshOpts = "-i /etc/vpush/ssh-key -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/root/known_hosts";
  remote = "/run/current-system/sw/bin/nix-daemon --stdio";

  noNetworkCaches = {
    nix.settings = {
      substituters = lib.mkForce [];
      experimental-features = ["nix-command"];
    };
  };
in
  pkgs.testers.runNixOSTest {
    name = "vpush-vm";

    nodes = {
      cache = {...}: {
        imports = [../vcache/default.nix noNetworkCaches];
        _module.args.settings = settingsFor "drakkar";
        # The test network, not the tailnet.
        systemd.services.vcache.environment.HOST = lib.mkForce "0.0.0.0";
        systemd.services.vcache.after = lib.mkForce ["network-online.target"];
        networking.firewall.allowedTCPPorts = [5100];

        services.openssh.enable = true;
        users.users.tom = {
          isNormalUser = true;
          openssh.authorizedKeys.keys = [keys.snakeOilEd25519PublicKey];
        };
        nix.settings.trusted-users = ["root" "tom"];

        virtualisation = {
          memorySize = 2048;
          diskSize = 4096;
          writableStoreUseTmpfs = false;
        };
      };

      builder = {...}: {
        imports = [./default.nix noNetworkCaches];
        _module.args.settings = settingsFor "huginn";
        features.nix.vpush = {
          sshDestination = "tom@cache";
          sshKeyFile = "/etc/vpush/ssh-key";
          interval = "2s";
        };
        environment.etc."vpush/ssh-key" = {
          source = keys.snakeOilEd25519PrivateKey;
          mode = "0400";
        };
        environment.etc."vpush/drv.nix".source = drv;
        environment.systemPackages = [pkgs.openssh];
        system.extraDependencies = [pkgs.bash pkgs.ruby pkgs.nodejs-slim];

        virtualisation = {
          memorySize = 2048;
          diskSize = 4096;
          writableStoreUseTmpfs = false;
        };
      };

      client = {...}: {
        imports = [noNetworkCaches];
        virtualisation = {
          memorySize = 1024;
          diskSize = 4096;
        };
      };
    };

    testScript = ''
      import time

      def build(tag):
          return builder.succeed(f"nix-build /etc/vpush/drv.nix --argstr tag {tag} --no-out-link").strip().splitlines()[-1]

      def closure(machine, path):
          return sorted(machine.succeed(f"nix-store -qR {path}").split())

      def spooled():
          return builder.succeed("find /var/lib/vpush/spool -maxdepth 1 -type f | wc -l").strip()

      start_all()
      cache.wait_for_unit("vcache.service")
      cache.wait_for_unit("sshd.service")
      cache.wait_for_open_port(5100)
      builder.wait_for_unit("vpush.service")
      client.wait_for_unit("multi-user.target")

      with subtest("a build is pushed, and a fresh store substitutes its whole closure from vcache"):
          out = build("a")
          paths = closure(builder, out)
          assert len(paths) > 10, paths
          cache_has = set(cache.succeed("nix-store -qR /run/current-system").split())
          print(f"CLOSURE {len(paths)} paths, {len([p for p in paths if p not in cache_has])} missing on the cache")
          builder.wait_until_succeeds("journalctl -u vpush -o cat | grep -q 'uploaded'", timeout=300)
          cache.wait_until_succeeds(f"nix-store --check-validity {out}", timeout=300)
          assert closure(cache, out) == paths
          builder.succeed("journalctl -u vpush -o cat | grep -q 'mode Some(Trusted)'")
          assert spooled() == "0", spooled()

          key = cache.succeed("cat /var/lib/vcache/public-key").strip()
          client.succeed(
              "nix-store --store /tmp/fresh --realise " + out
              + " --option substituters http://cache:5100"
              + f" --option trusted-public-keys '{key}' --option max-jobs 0"
          )
          fresh = sorted(client.succeed(f"nix-store --store /tmp/fresh -qR {out}").split())
          assert fresh == paths, (len(fresh), len(paths))
          print(f"HITRATE {len(fresh)}/{len(paths)} paths substituted from vcache, 0 built")

      with subtest("the cache is down during a build: the build succeeds and the item drains later"):
          cache.succeed("systemctl stop sshd.service")
          since = builder.succeed("date +%s").strip()
          out_b = build("b")
          builder.wait_until_succeeds(f"journalctl -u vpush --since @{since} -o cat | grep -q 'kept in the spool'", timeout=300)
          assert spooled() == "1", spooled()
          cache.fail(f"nix-store --check-validity {out_b}")
          cache.succeed("systemctl start sshd.service")
          builder.wait_until_succeeds("test \"$(find /var/lib/vpush/spool -maxdepth 1 -type f | wc -l)\" = 0", timeout=300)
          cache.succeed(f"nix-store --check-validity {out_b}")
          builder.fail("test -e /var/lib/vpush/spool/failed")

      with subtest("baseline: nix copy --to ssh-ng against vpush, same closure, empty cache"):
          builder.succeed("systemctl stop vpush.service")
          system_paths = set(cache.succeed("nix-store -qR /run/current-system").split())
          pushed = sorted(set(closure(cache, out) + closure(cache, out_b)) - system_paths)

          def wipe():
              cache.succeed("nix-store --delete " + " ".join(pushed))
              cache.fail(f"nix-store --check-validity {out}")

          def sent():
              return int(builder.succeed("cat /sys/class/net/eth1/statistics/tx_bytes"))

          def measured(label, cmd):
              wipe()
              b0, t0 = sent(), time.monotonic()
              builder.succeed(cmd)
              t, b = time.monotonic() - t0, sent() - b0
              assert closure(cache, out) == paths
              print(f"BASELINE {label}: {len(paths)} paths, {t:.2f}s wall, {b} bytes sent")

          missing = len([p for p in paths if p not in system_paths])
          print(f"BASELINE closure: {len(paths)} paths, {missing} missing on the cache")
          assert missing > 5, "the baseline closure must be mostly missing on the cache"
          measured(
              "nix copy --to ssh-ng",
              "NIX_SSHOPTS='${sshOpts}' nix copy --no-check-sigs --to ssh-ng://tom@cache " + out,
          )
          for jobs in [1, 2, 4]:
              builder.succeed("rm -rf /tmp/bspool && OUT_PATHS=" + out + " vpush hook --spool /tmp/bspool")
              measured(
                  f"vpush --jobs {jobs}",
                  "vpush daemon --once --spool /tmp/bspool --ssh tom@cache --ssh-program ssh"
                  + "".join(f" --ssh-arg {a}" for a in "${sshOpts}".split())
                  + " --remote-command '${remote}'"
                  + f" --jobs {jobs}",
              )
    '';
  }
