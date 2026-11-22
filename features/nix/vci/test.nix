# vci (GH-242) on a cache host, against a local repository standing in for GitHub:
#
#   nix build .#checks.x86_64-linux.vci-vm
#
#   cache    drakkar-like: features/nix/vcache serving its store, nix.settings.allowed-users
#            = ["@wheel"] as on every host, and vci, switched in LIVE (the boot generation
#            has no vci; the `vci` specialisation adds it). The forge is
#            file:///srv/repo.git (main, refs/pull/N/head) and /srv/pulls.json (GitHub's
#            open-PR list, as the API returns it). The flake has two hosts, alpha and beta,
#            whose toplevels are tiny derivations naming the commit (no nixpkgs, no
#            network), so every commit is a real build.
#   client   a fresh store (/tmp/fresh) that may only substitute (max-jobs 0) from the
#            cache's vcache.
#
# Covered:
#   1. switched in live: vci runs as its own user and reaches the restricted daemon;
#   2. main is built for every host first: done marker, two `built` records with eval and
#      build seconds, a root per host, the metrics;
#   3. a deploy of that commit does ZERO local builds: the client substitutes main's alpha
#      toplevel from vcache with max-jobs 0;
#   4. an open same-repository PR is built (with vdiff's summary against main) and a fork's
#      PR never is;
#   5. one host failing to evaluate is that host's result: the other host is built and the
#      commit is done;
#   6. a closed PR's roots are dropped, main's stay;
#   7. switched out live: the unit is gone, the roots stay; switched back in, it carries on.
{pkgs}: let
  inherit (pkgs) lib;

  settingsFor = hostname: {
    inherit hostname;
    username = "tom";
    userdir = "/home/tom";
    system = "x86_64-linux";
    stateVersion = "24.11";
  };

  # The repository's flake: no inputs, two hosts whose toplevel names the commit. `beta`
  # stops evaluating when the file `break-beta` exists in the commit.
  flake = pkgs.writeText "flake.nix" ''
    {
      outputs = {self}: let
        mk = name: {
          config.system.build.toplevel = derivation {
            name = "vci-test-''${name}";
            system = "x86_64-linux";
            builder = "/bin/sh";
            args = ["-c" "echo ''${name} ''${self.rev or "dirty"} > $out"];
          };
        };
      in {
        nixosConfigurations = {
          alpha = mk "alpha";
          beta =
            if builtins.pathExists ./break-beta
            then throw "beta is broken in this commit"
            else mk "beta";
        };
      };
    }
  '';

  noNetworkCaches = {
    nix.settings = {
      substituters = lib.mkForce [];
      experimental-features = ["nix-command" "flakes"];
    };
  };
in
  pkgs.testers.runNixOSTest {
    name = "vci-vm";

    nodes = {
      cache = {
        config,
        lib,
        ...
      }: {
        imports = [../vcache/default.nix ./default.nix noNetworkCaches];

        options.vmtest.vci = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };

        config = {
          _module.args.settings = settingsFor "drakkar";
          systemd.services.vcache.environment.HOST = lib.mkForce "0.0.0.0";
          systemd.services.vcache.after = lib.mkForce ["network-online.target"];
          networking.firewall.allowedTCPPorts = [5100];

          # Every host's restriction (features/nixos/users), told to vci as vhealth is told.
          nix.settings.allowed-users = ["@wheel"];
          features.nix.vci = {
            hosts = ["alpha" "beta"];
            url = "file:///srv/repo.git";
            pullsUrl = "file:///srv/pulls.json";
            repoSlug = "Industrial/nixos-dotfiles";
            interval = "3s";
            memoryMax = "1G";
            restrictedNixUsers = true;
          };
          # The boot generation has no vci; the `vci` specialisation switches it in.
          systemd.services.vci.enable = config.vmtest.vci;
          specialisation = lib.mkIf (!config.vmtest.vci) {
            vci.configuration.vmtest.vci = true;
          };

          # The test repository is root's; vci (another user) reads it.
          programs.git = {
            enable = true;
            config.safe.directory = "*";
          };
          system.switch.enable = true;
          services.prometheus.exporters.node.enable = true;
          virtualisation = {
            memorySize = 2048;
            diskSize = 4096;
            writableStoreUseTmpfs = false;
          };
        };
      };

      client = {...}: {
        imports = [noNetworkCaches];
        virtualisation.memorySize = 1024;
      };
    };

    testScript = ''
      import json

      prom = "/var/lib/prometheus-node-exporter-text/vci.prom"

      def git(cmd):
          return cache.succeed(f"git -C /srv/work {cmd}").strip()

      def commit(msg):
          git("add -A")
          git(f"-c user.name=t -c user.email=t@t commit -q -m '{msg}'")
          return git("rev-parse HEAD")

      def pulls(entries):
          body = [
              {"number": n, "head": {"sha": sha, "repo": {"full_name": repo}}, "base": {"repo": {"full_name": "Industrial/nixos-dotfiles"}}}
              for (n, sha, repo) in entries
          ]
          cache.succeed(f"echo '{json.dumps(body)}' > /srv/pulls.json.new && mv /srv/pulls.json.new /srv/pulls.json")

      def records():
          text = cache.succeed("cat /var/lib/vci/builds.jsonl 2>/dev/null || true")
          return [json.loads(l) for l in text.splitlines() if l.strip()]

      def built(sha):
          cache.wait_until_succeeds(f"test -e /var/lib/vci/done/{sha}", timeout=300)
          return {r["host"]: r for r in records() if r["sha"] == sha}

      def roots():
          return cache.succeed("ls /var/lib/vci/roots").split()

      def as_vci(cmd):
          return f"setpriv --reuid vci --regid vci --clear-groups -- {cmd}"

      start_all()
      cache.wait_for_unit("vcache.service")
      cache.wait_for_open_port(5100)
      cache.fail("systemctl is-active vci.service")

      # The forge: a work tree, its bare clone, and an empty open-PR list.
      cache.succeed("mkdir -p /srv/work && git -C /srv/work init -q -b main")
      cache.succeed("cp ${flake} /srv/work/flake.nix && chmod u+w /srv/work/flake.nix")
      main1 = commit("main 1")
      cache.succeed("git clone -q --bare /srv/work /srv/repo.git")
      pulls([])

      with subtest("switched in live: vci runs as its own user and reaches the restricted daemon"):
          base = cache.succeed("readlink -f /run/booted-system").strip()
          cache.succeed(f"{base}/specialisation/vci/bin/switch-to-configuration test")
          cache.wait_for_unit("vci.service")
          t.assertEqual(cache.succeed("systemctl show -p User --value vci").strip(), "vci")
          cache.succeed(as_vci("nix-store --store daemon -q --hash /run/current-system"))

      with subtest("main is built first, for every host: records, roots and metrics"):
          r = built(main1)
          t.assertEqual(sorted(r), ["alpha", "beta"])
          for host in ["alpha", "beta"]:
              t.assertEqual((r[host]["result"], r[host]["ref"]), ("built", "main"), r[host])
              t.assertTrue(r[host]["drv"].endswith(".drv") and r[host]["out"].startswith("/nix/store/"), r[host])
              out = cache.succeed(f"readlink -f /var/lib/vci/roots/main-{host}").strip()
              t.assertEqual(out, r[host]["out"])
              t.assertEqual(cache.succeed(f"cat {out}").split(), [host, main1])
          cache.wait_until_succeeds(f"grep -q '^vci_build_seconds{{host=\"alpha\",ref=\"main\"}} ' {prom}", timeout=60)
          cache.succeed(f"grep -q '^vci_commits_built_total 1$' {prom}")
          # The ledger and the metrics are readable by anyone.
          cache.succeed(as_vci(f"cat {prom}") + " > /dev/null")

      with subtest("a deploy of a vci-built commit does zero local builds"):
          out = records()[0]["out"]
          key = cache.succeed("cat /var/lib/vcache/public-key").strip()
          client.succeed(
              "nix-store --store /tmp/fresh --realise " + out
              + " --option substituters http://cache:5100"
              + f" --option trusted-public-keys '{key}' --option max-jobs 0"
          )
          client.succeed(f"nix-store --store /tmp/fresh --check-validity {out}")

      with subtest("an open same-repository PR is built against main; a fork's PR never is"):
          git("checkout -q -b feature")
          cache.succeed("echo pr > /srv/work/pr.txt")
          pr = commit("pr 1")
          git("checkout -q -b fork main")
          cache.succeed("echo fork > /srv/work/fork.txt")
          fork = commit("fork pr")
          git("checkout -q main")
          git(f"push -q /srv/repo.git {pr}:refs/pull/1/head {fork}:refs/pull/2/head")
          pulls([(1, pr, "Industrial/nixos-dotfiles"), (2, fork, "someone/nixos-dotfiles")])
          r = built(pr)
          for host in ["alpha", "beta"]:
              t.assertEqual((r[host]["result"], r[host]["ref"]), ("built", "pull/1"), r[host])
              t.assertIsNotNone(r[host]["diff"], r[host])
          t.assertIn("pull-1-alpha", roots())
          # Steps go on; the fork's commit is never evaluated or built.
          cache.wait_until_succeeds(f"grep -q '^vci_pending_commits 0$' {prom}", timeout=60)
          cache.fail(f"test -e /var/lib/vci/done/{fork}")
          t.assertEqual([x for x in records() if x["sha"] == fork], [])

      with subtest("one host failing to evaluate is its own result; the commit is done"):
          cache.succeed("touch /srv/work/break-beta")
          main2 = commit("main 2: beta breaks")
          git("push -q /srv/repo.git main")
          r = built(main2)
          t.assertEqual(r["alpha"]["result"], "built")
          t.assertEqual(r["beta"]["result"], "eval-failed")
          t.assertIn("beta is broken in this commit", r["beta"]["error"])
          cache.succeed(f"grep -q '^vci_last_result{{host=\"beta\",ref=\"main\",result=\"eval-failed\"}} 1$' {prom}")

      with subtest("a closed PR's roots are dropped; main's stay"):
          pulls([])
          cache.wait_until_fails("test -e /var/lib/vci/roots/pull-1-alpha", timeout=60)
          t.assertIn("main-alpha", roots())

      with subtest("switched out live, then back in"):
          cache.succeed(f"{base}/bin/switch-to-configuration test")
          cache.fail("systemctl is-active vci.service")
          t.assertIn("main-alpha", roots())
          cache.succeed(f"{base}/specialisation/vci/bin/switch-to-configuration test")
          cache.wait_for_unit("vci.service")
          cache.succeed("rm /srv/work/break-beta")
          main3 = commit("main 3: beta fixed")
          git("push -q /srv/repo.git main")
          r = built(main3)
          t.assertEqual(sorted(x["result"] for x in r.values()), ["built", "built"])
          cache.succeed(as_vci("nix-store --store daemon -q --hash /run/current-system"))
    '';
  }
