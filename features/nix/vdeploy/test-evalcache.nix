# vdeploy's eval cache (GH-243), switched into and out of a running, hardened consumer:
#
#   nix build .#checks.x86_64-linux.vdeploy-evalcache-vm
#
#   cache     drakkar-like: vci (GH-242) building the consumer's toplevel for every commit of
#             the fleet repository (/srv/repo.git, also served over git:// to the consumer),
#             vcache serving the store and vci's veval records, signed with a test key; a
#             second, plain HTTP server on :8001 stands in for a cache that hands out
#             unsigned records.
#   consumer  vdeploy (observe mode), the STIG base-safe profile (mimir's), the restricted
#             daemon (allowed-users = @wheel, as on every host), substituting only from the
#             cache. It boots WITHOUT the eval cache (--no-eval-cache); the `cache`
#             specialisation switches it in live, and switching back takes it away again.
#
# The fleet repository's flake has no inputs; its toplevel is a tiny derivation naming the
# commit (`self.rev`), so every commit is a new drv, a new out and a new vci record.
#
# Covered:
#   1. no eval cache: a commit vci already built is evaluated here anyway ("eval cache off"),
#      and the evaluation shows in vdeploy's Nix eval cache;
#   2. switched in live: a commit vci built is planned with vci's record and NO local
#      evaluation (the journal's hit, the hit counter, no new Nix eval-cache entry, the
#      record's drv), its out substituted from the cache;
#   3. a tampered record (its Out pointed at another commit's out, then signed by the
#      cache as it serves every record): refused against the cache's narinfo, evaluated
#      here, counted as a fallback, and the plan is still the right commit's;
#   4. an unsigned record (the :8001 stand-in, asked first): a miss, never an error, evaluated
#      here, and the reason is in the journal;
#   5. switched out live: --no-eval-cache again, evaluated here, the counters unchanged;
#   after each switch: alice (no root) reads the plan and the metrics, and fetches the
#   record from the cache; vci's own user reads its records on the cache.
{pkgs}: let
  inherit (pkgs) busybox;
  testKey = import ./test-key.nix {inherit pkgs;};
  # A cache signing key for this test only (`nix key generate-secret --key-name test-vcache-1`).
  cacheSecret = "test-vcache-1:2kDtNwcDPPeTWBkV+9ETrTMKazto/WkPmn96l6drwlg4JEOzCseS8/jfEJpvdqohsbpOPuVkamCK2c73bhibHg==";
  cachePublic = "test-vcache-1:OCRDswrHkvP43xCab3aqIbG6Tj7lZGpgitnO924Ymx4=";
  lock = pkgs.writeText "flake.lock" ''{"nodes":{"root":{}},"root":"root","version":7}'';
  flake = pkgs.writeText "flake.nix" ''
    {
      outputs = {self}: {
        nixosConfigurations.consumer.config.system.build.toplevel = derivation {
          name = "vdeploy-evalcache-system";
          system = "x86_64-linux";
          builder = "${busybox}/bin/sh";
          args = ["-c" "${busybox}/bin/mkdir -p $out; echo ''${self.rev or "dirty"} > $out/rev"];
        };
      };
    }
  '';
  offline = {lib, ...}: {
    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      # The toplevel's builder is busybox, named without string context: no sandbox.
      sandbox = false;
    };
    system.extraDependencies = [busybox];
    programs.git = {
      enable = true;
      config.safe.directory = "*";
    };
  };
in
  pkgs.testers.runNixOSTest {
    name = "vdeploy-evalcache-vm";

    nodes.cache = {lib, ...}: {
      imports = [../vcache/default.nix ../vci/default.nix offline];
      # The flag vci's feature wrapper declares: vcache serves vci's records where it is on.
      options.features.nix.vci.enable = lib.mkOption {default = true;};
      config = {
        _module.args.settings = {
          hostname = "drakkar";
          username = "tom";
          userdir = "/home/tom";
          system = "x86_64-linux";
          stateVersion = "24.11";
        };
        nix.settings.substituters = lib.mkForce [];
        systemd.services.vcache.environment = {
          HOST = lib.mkForce "0.0.0.0";
          VCACHE_SIGN_KEY_FILE = lib.mkForce "/etc/vcache-test-key";
        };
        systemd.services.vcache.after = lib.mkForce ["network-online.target"];
        environment.etc."vcache-test-key".text = cacheSecret;
        nix.settings.allowed-users = ["@wheel"];
        features.nix.vci = {
          hosts = ["consumer"];
          url = "file:///srv/repo.git";
          pulls = false;
          interval = "3s";
          memoryMax = "1G";
          restrictedNixUsers = true;
          maxLoad = 100;
          minFreeMemory = "64M";
        };
        # The consumer fetches main over git://.
        services.gitDaemon = {
          enable = true;
          basePath = "/srv";
          exportAll = true;
        };
        # A cache that hands out unsigned records: plain files, no signature.
        systemd.services.unsigned = {
          wantedBy = ["multi-user.target"];
          serviceConfig.ExecStart = "${busybox}/bin/httpd -f -p 8001 -h /srv/unsigned";
          preStart = "mkdir -p /srv/unsigned/veval";
        };
        networking.firewall.allowedTCPPorts = [5100 8001 9418];
        services.prometheus.exporters.node.enable = true;
        environment.systemPackages = [pkgs.gnupg];
        virtualisation = {
          memorySize = 2048;
          diskSize = 4096;
        };
      };
    };

    nodes.consumer = {
      config,
      lib,
      ...
    }: {
      imports = [./default.nix ../../security/stig/profiles/base-safe.nix offline];

      options.vmtest.cache = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      config = {
        services.timesyncd.enable = lib.mkForce true;
        system.switch.enable = true;
        features.nix.vdeploy = {
          url = "git://cache/repo.git";
          interval = "2s";
          dotfiles.enable = false;
          trustedSigningKeys = ["${testKey}/public.asc"];
          # Boots without the eval cache; the `cache` specialisation switches it in.
          evalCache = {
            enable = config.vmtest.cache;
            # The unsigned stand-in first, so it is always asked.
            caches = [
              {
                url = "http://cache:8001";
                publicKey = cachePublic;
              }
              {
                url = "http://cache:5100";
                publicKey = cachePublic;
              }
            ];
          };
        };
        specialisation = lib.mkIf (!config.vmtest.cache) {
          cache.configuration.vmtest.cache = true;
        };
        nix.settings = {
          substituters = lib.mkForce ["http://cache:5100"];
          trusted-public-keys = lib.mkForce [cachePublic];
          allowed-users = ["@wheel"];
        };
        users.users.alice = {
          isNormalUser = true;
          uid = 1000;
          # The restricted daemon answers @wheel, as the operator is on every host.
          extraGroups = ["wheel"];
        };
        services.prometheus.exporters.node.enable = true;
        environment.systemPackages = [pkgs.curl pkgs.jq];
        virtualisation = {
          memorySize = 2048;
          cores = 2;
        };
      };
    };

    testScript = {nodes, ...}: let
      base = nodes.consumer.system.build.toplevel;
    in ''
      import json

      prom = "/var/lib/prometheus-node-exporter-text/vdeploy.prom"
      evalcache = "/var/lib/vdeploy/.cache/nix"

      def as_alice(cmd):
          return f"su - alice -c {json.dumps(cmd)}"

      def as_vci(cmd):
          return f"setpriv --reuid vci --regid vci --clear-groups -- {cmd}"

      def git(cmd):
          return cache.succeed(f"git -C /srv/work {cmd}").strip()

      def commit(n):
          cache.succeed(f"echo {n} > /srv/work/n")
          git("add -A")
          git(f"-c user.name=t -c user.email=t@t -c user.signingkey=$(cat ${testKey}/fingerprint) -c commit.gpgsign=true -c gpg.program=${pkgs.gnupg}/bin/gpg commit -q -m 'commit {n}'")
          git("push -q /srv/repo.git main")
          return git("rev-parse HEAD")

      def vci_built(sha):
          cache.wait_until_succeeds(f"test -e /var/lib/vci/done/{sha}", timeout=300)
          lines = cache.succeed("cat /var/lib/vci/builds.jsonl").splitlines()
          r = [json.loads(l) for l in lines if l.strip() and json.loads(l)["sha"] == sha][0]
          t.assertEqual(r["result"], "built", r)
          return r

      def record_file(sha):
          return cache.succeed(f"grep -l '^Commit: {sha}$' /var/lib/vci/veval/*.veval").strip()

      def planned(sha):
          consumer.wait_until_succeeds(f"jq -e '.commit == \"{sha}\"' /var/lib/vdeploy/plan.json", timeout=300)
          return json.loads(consumer.succeed(as_alice("cat /var/lib/vdeploy/plan.json")))

      def metric(name):
          consumer.wait_until_succeeds(f"grep -q '^{name} ' {prom}", timeout=60)
          return int(float(consumer.succeed(as_alice(f"grep '^{name} ' {prom}")).split()[1]))

      def metric_is(name, value):
          # The metrics are rewritten after the plan: wait for the value, as alice reads it.
          consumer.wait_until_succeeds(as_alice(f"grep -qx '{name} {value}' {prom}"), timeout=60)

      def evaluations():
          # Every flake evaluation leaves an entry in vdeploy's Nix eval cache.
          return int(consumer.succeed(f"find {evalcache} -name '*.sqlite' -path '*eval-cache*' 2>/dev/null | wc -l").strip())

      def plan_once(sha):
          # The agent plans main's tip when it starts: hold it while the cache gets ready.
          consumer.succeed("systemctl start vdeploy.service")
          return planned(sha)

      def journal_since(cursor):
          return consumer.succeed(f"journalctl -u vdeploy -o cat --after-cursor='{cursor}'")

      def cursor():
          return consumer.succeed("journalctl -u vdeploy -n 0 --show-cursor -o cat | sed -n 's/^-- cursor: //p'").strip()

      def probes():
          consumer.succeed(as_alice("timeout 60 nix-store --store daemon -q --hash /run/current-system"))
          consumer.succeed(as_alice(f"cat {prom} /var/lib/vdeploy/plan.json > /dev/null"))
          cache.succeed(as_vci("ls /var/lib/vci/veval"))

      start_all()
      cache.wait_for_unit("vcache.service")
      cache.wait_for_open_port(5100)
      cache.wait_for_unit("git-daemon.service")
      consumer.wait_for_unit("multi-user.target")
      consumer.succeed("systemctl stop vdeploy.service")

      # The fleet repository: signed commits (GH-221), a bare clone vci and git:// read.
      cache.succeed("gpg --batch --import ${testKey}/secret.asc")
      cache.succeed("mkdir -p /srv/work && git -C /srv/work init -q -b main")
      cache.succeed("cp ${flake} /srv/work/flake.nix && cp ${lock} /srv/work/flake.lock")
      cache.succeed("git init -q --bare -b main /srv/repo.git")
      cache.succeed("touch /srv/repo.git/git-daemon-export-ok")

      with subtest("no eval cache: a commit vci built is evaluated here anyway"):
          z = commit(0)
          vci_built(z)
          c = cursor()
          p = plan_once(z)
          t.assertEqual(p["action"], "switch", p)
          out = journal_since(c)
          t.assertIn("eval cache off, evaluating", out)
          t.assertGreater(evaluations(), 0)
          t.assertIn("--no-eval-cache", consumer.succeed("systemctl show -p ExecStart --value vdeploy"))
          probes()

      with subtest("switched in live: vci's record is planned with no local evaluation"):
          consumer.succeed("systemctl stop vdeploy.service")
          a = commit(1)
          r = vci_built(a)
          before = evaluations()
          c = cursor()
          consumer.succeed("${base}/specialisation/cache/bin/switch-to-configuration test")
          consumer.succeed("systemctl start vdeploy.service")
          p = planned(a)
          out = journal_since(c)
          t.assertIn("eval cache hit: " + r["drv"], out)
          t.assertEqual((p["drv"], p["out"]), (r["drv"], r["out"]), p)
          t.assertEqual(p["realised"], "fetched", p)
          t.assertEqual(evaluations(), before)
          metric_is("vdeploy_eval_cache_hits_total", 1)
          t.assertGreaterEqual(metric("vdeploy_eval_seconds_saved_total"), 0)
          metric_is("vdeploy_eval_cache_fallbacks_total", 0)
          t.assertEqual(consumer.succeed(f"cat {r['out']}/rev").strip(), a)
          # alice fetches the same record from the cache, signed.
          rid = record_file(a).split("/")[-1]
          t.assertIn("Sig: test-vcache-1:", consumer.succeed(as_alice(f"curl -sf http://cache:5100/veval/{rid}")))
          probes()

      with subtest("a tampered record is refused against the narinfo, evaluated here, counted"):
          consumer.succeed("systemctl stop vdeploy.service")
          b = commit(2)
          rb = vci_built(b)
          # Out pointed at commit 1's out: vcache signs it as it signs every record it serves.
          cache.succeed(f"sed -i 's|^Out: .*|Out: {r['out']}|' {record_file(b)}")
          before = evaluations()
          c = cursor()
          p = plan_once(b)
          out = journal_since(c)
          t.assertIn("eval cache record refused, evaluating", out)
          t.assertEqual((p["drv"], p["out"]), (rb["drv"], rb["out"]), p)
          t.assertGreater(evaluations(), before)
          metric_is("vdeploy_eval_cache_fallbacks_total", 1)
          metric_is("vdeploy_eval_cache_hits_total", 1)

      with subtest("an unsigned record is a miss, never an error: evaluated here"):
          consumer.succeed("systemctl stop vdeploy.service")
          d = commit(3)
          rd = vci_built(d)
          # The real cache no longer has it; the stand-in has vci's file, unsigned.
          cache.succeed(f"mv {record_file(d)} /srv/unsigned/veval/")
          misses = metric("vdeploy_eval_cache_misses_total")
          before = evaluations()
          c = cursor()
          p = plan_once(d)
          out = journal_since(c)
          t.assertIn("no trusted signature", out)
          t.assertEqual((p["drv"], p["out"]), (rd["drv"], rd["out"]), p)
          t.assertGreater(evaluations(), before)
          metric_is("vdeploy_eval_cache_misses_total", misses + 1)
          consumer.succeed("systemctl is-active vdeploy.service")
          probes()

      with subtest("switched out live: --no-eval-cache again, evaluated here, counters kept"):
          consumer.succeed("systemctl stop vdeploy.service")
          e = commit(4)
          vci_built(e)
          before = evaluations()
          c = cursor()
          consumer.succeed("${base}/bin/switch-to-configuration test")
          consumer.succeed("systemctl start vdeploy.service")
          p = planned(e)
          out = journal_since(c)
          t.assertIn("eval cache off, evaluating", out)
          t.assertGreater(evaluations(), before)
          t.assertIn("--no-eval-cache", consumer.succeed("systemctl show -p ExecStart --value vdeploy"))
          metric_is("vdeploy_eval_cache_hits_total", 1)
          probes()
    '';
  }
