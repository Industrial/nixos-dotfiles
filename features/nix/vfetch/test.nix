# NixOS VM test for features/nix/vfetch: a path the client does not have is substituted
# through vfetch serve on localhost, from an upstream binary cache, and vfetch serve's
# log shows the narinfo and the NAR going through it.
#
#   cache:  nix-serve over its own store, which has `payload` (system.extraDependencies),
#           signing with a key made at the start of the test.
#   client: the feature; its substituters are [vfetch serve, the cache]. It does not
#           have `payload` (not in its closure), so `nix-store -r` must substitute it.
#
#   nix build .#checks.x86_64-linux.vfetch-vm
{pkgs}: let
  payload = pkgs.writeText "vfetch-payload" "substituted through vfetch serve\n";
in
  pkgs.testers.runNixOSTest {
    name = "vfetch-vm";

    nodes = {
      cache = {lib, ...}: {
        system.extraDependencies = [payload];
        services.nix-serve = {
          enable = true;
          openFirewall = true;
          secretKeyFile = "/run/cache-key/secret";
        };
        # Started by the test, once the key exists.
        systemd.services.nix-serve.wantedBy = lib.mkForce [];
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
      start_all()

      with subtest("the cache serves the payload, signed"):
          cache.succeed("mkdir -p /run/cache-key")
          cache.succeed("nix-store --generate-binary-cache-key vfetch-test-cache-1 /run/cache-key/secret /run/cache-key/public")
          cache.succeed("systemctl start nix-serve")
          cache.wait_for_open_port(5000)
          public = cache.succeed("cat /run/cache-key/public").strip()

      with subtest("vfetch serve answers on localhost, ahead of the cache"):
          client.succeed(f"echo '{public}' > /run/vfetch-test-key")
          client.succeed("systemctl restart vfetch-serve")
          client.wait_for_open_port(5101)
          client.succeed("curl -sf http://127.0.0.1:5101/nix-cache-info | grep -qx 'Priority: 10'")
          client.succeed("grep -E '^substituters = http://127.0.0.1:5101 ' /etc/nix/nix.conf")
          client.fail("nix-store -q --hash ${payload}")

      with subtest("a nix substitution of a path the client lacks goes through vfetch serve"):
          out = client.succeed(
              f"nix-store -r ${payload} --option extra-trusted-public-keys '{public}' 2>&1"
          )
          assert "127.0.0.1:5101" in out, out
          client.succeed("grep -qx 'substituted through vfetch serve' ${payload}")
          log = client.succeed("journalctl -u vfetch-serve -o cat")
          assert "narinfo ${payload} from http://cache:5000" in log, log
          assert "nar http://cache:5000/nar/" in log, log
          client.succeed("nix-store --verify-path ${payload}")
    '';
  }
