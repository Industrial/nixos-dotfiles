# Two-node acceptance test and fan-out benchmark for vbuild, against stock
# build-remote in the same VM pair (the fleet's builders are offline, decision D4).
#
#   nix build .#checks.x86_64-linux.vbuild-vm
#
# client: features/fleet/vbuild.nix (build-hook = vbuild) with one remote
#   builder in nix.buildMachines (so /etc/nix/machines, as on the fleet). The
#   builder advertises `vbuild-remote`, a feature the client lacks, so a
#   derivation that requires it can only be built there.
# builder: sshd, root's key authorised (root is a trusted user).
#
# The baseline arm runs the same nix-build with `--option build-hook "nix
# __build-remote"`, Nix's default hook. Numbers are printed as `vbuild-bench`
# lines; they are what the issue reports.
#
# CI does not build VM tests on pull requests (only the STIG job, on main), so
# this is run by hand: on drakkar through .tmp/vnla/vmtest.sh.
{pkgs}: let
  inherit (pkgs) lib nix;
  keys = import (pkgs.path + "/nixos/tests/ssh-keys.nix") pkgs;

  # Derivations with no inputs but busybox, so neither machine needs a
  # substituter. `seed` gives every arm its own output paths.
  drvs = pkgs.writeText "vbuild-test-drvs.nix" ''
    { seed ? "0" }:
    let
      bb = builtins.storePath "${pkgs.busybox}";
      mk = name: script: features: derivation {
        name = "vbuild-''${name}-''${seed}";
        system = "x86_64-linux";
        builder = "''${bb}/bin/sh";
        args = [ "-c" script ];
        PATH = "''${bb}/bin";
        requiredSystemFeatures = features;
      };
      fan = i: mk "fan-''${toString i}" "sleep 4; echo ''${toString i} > $out" [ "vbuild-remote" ];
    in {
      remote = mk "remote" "echo built-remotely > $out" [ "vbuild-remote" ];
      plain = mk "plain" "echo built-here > $out" [ ];
      fan = builtins.listToAttrs (map (i: { name = "f''${toString i}"; value = fan i; }) (builtins.genList (x: x) 8));
    }
  '';

  common = {
    virtualisation.memorySize = 1536;
    nix.settings = {
      substituters = lib.mkForce [];
      sandbox = true;
    };
  };
in
  pkgs.testers.runNixOSTest {
    name = "vbuild";

    nodes.builder = {
      imports = [common];
      virtualisation.cores = 4;
      services.openssh.enable = true;
      users.users.root.openssh.authorizedKeys.keys = [keys.snakeOilPublicKey];
      nix.settings.system-features = ["vbuild-remote" "nixos-test" "benchmark"];
    };

    nodes.client = {
      imports = [common ../../../features/fleet/vbuild.nix];
      virtualisation.cores = 2;
      virtualisation.additionalPaths = [pkgs.busybox drvs];
      nix.distributedBuilds = true;
      nix.buildMachines = [
        {
          hostName = "builder";
          sshUser = "root";
          sshKey = "/root/.ssh/id_snakeoil";
          system = "x86_64-linux";
          maxJobs = 4;
          speedFactor = 1;
          supportedFeatures = ["vbuild-remote"];
        }
      ];
      nix.settings.builders-use-substitutes = false;
      programs.ssh.extraConfig = ''
        Host builder
          StrictHostKeyChecking no
          UserKnownHostsFile /dev/null
      '';
    };

    testScript = ''
      def ms(machine, cmd):
          """Run cmd on machine, return (wall ms, stdout)."""
          out = machine.succeed(
              "s=$(date +%s%N); out=$(" + cmd + "); e=$(date +%s%N); "
              + "echo $(( (e - s) / 1000000 )); echo \"$out\""
          )
          lines = out.strip().split("\n")
          return int(lines[0]), "\n".join(lines[1:])

      build_remote = "${nix}/bin/nix __build-remote"
      nb = "nix-build ${drvs} --no-out-link --max-jobs 8"

      start_all()
      builder.wait_for_unit("sshd.service")
      client.wait_for_unit("multi-user.target")
      client.succeed(
          "mkdir -p /root/.ssh && install -m 600 ${keys.snakeOilPrivateKey} /root/.ssh/id_snakeoil"
      )
      client.succeed("ssh -i /root/.ssh/id_snakeoil root@builder true")
      client.succeed("grep -q '^build-hook = .*/bin/vbuild' /etc/nix/nix.conf")

      with subtest("a derivation needing a builder-only feature is built on the builder"):
          t, out = ms(client, nb + " -A remote --argstr seed accept")
          out = out.strip().split("\n")[-1]
          builder.succeed(f"nix-store --check-validity {out}")
          client.succeed(f"nix-store --verify-path {out}")
          assert client.succeed(f"cat {out}").strip() == "built-remotely"
          print(f"vbuild-bench accept ms={t}")

      with subtest("the output came back valid, and registered"):
          client.succeed(f"nix-store --check-validity {out}")
          client.succeed(f"nix path-info --extra-experimental-features nix-command --json {out} | grep -q narHash")

      with subtest("the nix-copy fallback copier works too"):
          hook = client.succeed("sed -n 's/^build-hook = //p' /etc/nix/nix.conf").strip()
          t, out2 = ms(client, nb + f" -A remote --argstr seed fallback --option build-hook '{hook} --copier nix-copy'")
          out2 = out2.strip().split("\n")[-1]
          builder.succeed(f"nix-store --check-validity {out2}")
          client.succeed(f"nix-store --verify-path {out2}")
          print(f"vbuild-bench accept-nix-copy ms={t}")

      with subtest("builder down: vbuild declines at once and the build runs here"):
          builder.block()
          client.succeed("rm -rf /nix/var/nix/vbuild/probe")
          t, out = ms(client, nb + " -A plain --argstr seed down-vbuild")
          out = out.strip().split("\n")[-1]
          assert client.succeed(f"cat {out}").strip() == "built-here"
          print(f"vbuild-bench down-vbuild ms={t}")
          assert t < 20000, f"vbuild took {t} ms to fall back to a local build"

      with subtest("builder down: the build-remote baseline"):
          # Not asserted on: it is the failure mode being replaced. Bounded so
          # that a hang shows as a number, not a stuck test.
          rc, out = client.execute(
              "s=$(date +%s%N); timeout 600 " + nb
              + f" -A plain --argstr seed down-build-remote --option build-hook '{build_remote}' >&2; "
              + "rc=$?; e=$(date +%s%N); echo $(( (e - s) / 1000000 )) $rc"
          )
          t, status = out.strip().split()[-2:]
          print(f"vbuild-bench down-build-remote ms={t} exit={status}")
          builder.unblock()
          builder.succeed("true")
          client.wait_until_succeeds("ssh -i /root/.ssh/id_snakeoil root@builder true", timeout=60)
          # The ssh master from before the outage may be wedged on a dead TCP
          # connection (ServerAlive ends it within ~15 s); start the next arm clean.
          # ([C]: so the pattern does not match this shell's own command line.)
          client.succeed("pkill -f '[C]ontrolPersist' || true; rm -rf /nix/var/nix/vbuild/ssh/* /nix/var/nix/vbuild/probe")

      with subtest("fan-out: 8 independent derivations, build-remote then vbuild"):
          ms(client, nb + " -A remote --argstr seed warm")
          t_br, _ = ms(client, nb + f" -A fan --argstr seed fan-build-remote --option build-hook '{build_remote}'")
          t_vb, outs = ms(client, nb + " -A fan --argstr seed fan-vbuild")
          for o in outs.strip().split("\n"):
              builder.succeed(f"nix-store --check-validity {o}")
              client.succeed(f"nix-store --verify-path {o}")
          print(f"vbuild-bench fan-out build-remote ms={t_br}")
          print(f"vbuild-bench fan-out vbuild ms={t_vb}")
          # The acceptance bound is "no slower than build-remote"; 15% covers VM
          # timing noise (the two measured within 1% of each other, 2026-11-21).
          assert t_vb <= t_br * 1.15, f"vbuild fan-out {t_vb} ms vs build-remote {t_br} ms"
    '';
  }
