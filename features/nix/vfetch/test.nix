# NixOS VM test for features/nix/vfetch: a path the client does not have is substituted
# through vfetch serve on localhost, from an upstream binary cache, and vfetch serve's
# log shows the narinfo and the NAR going through it. With vfetch serve stopped, Nix
# substitutes from the cache behind it within seconds; killed, systemd restarts it.
#
#   cache:  a plain HTTP binary cache (`nix copy --to file://`, served by python's
#           http.server) of `payload` and `fallback`, which are in its store
#           (system.extraDependencies), signed with a key made at the start of the test.
#           (nix-serve is not used: its Perl bindings fail to load in this nixpkgs.)
#   client: the feature; its substituters are [vfetch serve, the cache]. It does not
#           have `payload` (not in its closure), so `nix-store -r` must substitute it.
#
#   nix build .#checks.x86_64-linux.vfetch-vm
{pkgs}: let
  payload = pkgs.writeText "vfetch-payload" "substituted through vfetch serve\n";
  # Fetched with vfetch serve stopped: Nix must go on to the cache by itself.
  fallback = pkgs.writeText "vfetch-fallback" "substituted around a stopped vfetch serve\n";
in
  pkgs.testers.runNixOSTest {
    name = "vfetch-vm";

    nodes = {
      cache = {...}: {
        system.extraDependencies = [payload fallback];
        environment.systemPackages = [pkgs.python3];
        networking.firewall.allowedTCPPorts = [5000];
      };

      client = {...}: {
        imports = [./default.nix];
        nix.settings.substituters = ["http://cache:5000"];
        # vfetch serve reads the cache's public key from here (the test writes it).
        systemd.services.vfetch-serve.environment.VFETCH_TRUSTED_KEY_FILE = "/run/vfetch-test-key";
        environment.systemPackages = [pkgs.curl];
      };
    };

    testScript = ''
      import time

      start_all()

      with subtest("the cache serves the payload, signed"):
          cache.succeed("mkdir -p /run/cache-key")
          cache.succeed("nix-store --generate-binary-cache-key vfetch-test-cache-1 /run/cache-key/secret /run/cache-key/public")
          cache.succeed("nix --extra-experimental-features nix-command store sign --key-file /run/cache-key/secret ${payload} ${fallback}")
          cache.succeed("nix --extra-experimental-features nix-command copy --to file:///srv/cache ${payload} ${fallback}")
          # As a real cache does; with no Priority line Nix would sort it at 0, first.
          cache.succeed("echo 'Priority: 40' >> /srv/cache/nix-cache-info")
          cache.succeed("systemd-run --unit cache-http python3 -m http.server 5000 --directory /srv/cache")
          cache.wait_for_open_port(5000)
          cache.succeed("grep -q '^Sig: vfetch-test-cache-1:' /srv/cache/$(basename ${payload} | cut -c1-32).narinfo")
          public = cache.succeed("cat /run/cache-key/public").strip()

      with subtest("vfetch serve answers on localhost, ahead of the cache"):
          client.succeed(f"echo '{public}' > /run/vfetch-test-key")
          client.succeed("systemctl restart vfetch-serve")
          client.wait_for_open_port(5101)
          client.succeed("curl -sf http://127.0.0.1:5101/nix-cache-info | grep -qx 'Priority: 1'")
          client.succeed("grep -E '^substituters = http://127.0.0.1:5101 ' /etc/nix/nix.conf")
          client.fail("nix-store -q --hash ${payload}")

      with subtest("a nix substitution of a path the client lacks goes through vfetch serve"):
          out = client.succeed(
              f"nix-store -r ${payload} --option extra-trusted-public-keys '{public}' 2>&1"
          )
          assert "127.0.0.1:5101" in out, out
          client.succeed("grep -qx 'substituted through vfetch serve' ${payload}")
          journal = client.succeed("journalctl -u vfetch-serve -o cat")
          assert "narinfo ${payload} from http://cache:5000" in journal, journal
          assert "nar http://cache:5000/nar/" in journal, journal
          client.succeed("nix-store --verify-path ${payload}")

      with subtest("with vfetch serve down, nix substitutes from the next cache, promptly"):
          client.succeed("systemctl stop vfetch-serve")
          client.fail("curl -sf http://127.0.0.1:5101/nix-cache-info")
          client.fail("nix-store -q --hash ${fallback}")
          start = time.monotonic()
          out = client.succeed(
              f"timeout 60 nix-store -r ${fallback} --option extra-trusted-public-keys '{public}' 2>&1"
          )
          took = time.monotonic() - start
          assert "http://cache:5000" in out, out
          assert took < 30, f"the fallback took {took:.1f}s"
          client.succeed("nix-store --verify-path ${fallback}")

      with subtest("a vfetch serve that dies is restarted"):
          client.succeed("systemctl start vfetch-serve")
          client.wait_for_open_port(5101)
          client.succeed("systemctl kill --signal=KILL vfetch-serve")
          client.wait_until_succeeds("curl -sf http://127.0.0.1:5101/nix-cache-info", timeout=30)
    '';
  }
