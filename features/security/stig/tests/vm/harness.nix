# Harness turning per-control test specs into NixOS VM tests.
#
# Why this exists: all 103 checks in the Anduril NixOS STIG are manual shell commands run
# against a booted machine. The assay suites next to each control prove what the configuration
# *declares*; only a booted VM can prove what the running system *does*. For seven controls
# (see security.stig.deferredVerification) a VM is the ONLY way to verify them at all.
#
# A spec is data:
#
#   {
#     id = "V-268141";
#     description = "IPv4 TCP syncookies";
#     modules = [ ../../controls/V-268141.nix ];
#     script = ''
#       machine.succeed("sysctl -n net.ipv4.tcp_syncookies | grep -qx 1")
#     '';
#   }
#
# Specs are grouped by subsystem into sibling files rather than one file per control: 103
# control modules already come with 103 colocated suites, and another 206 files for the VM
# layer would bury the scripts rather than surface them. The per-control granularity lives in
# the `id` field, and each spec still becomes its own independently runnable derivation.
#
# `script` is translated from the control's own check content. Where our implementation
# deliberately diverges from the published fix text — V-268105's SYSLOG instead of HALT,
# V-268160's equality-tested kptr_restrict — the script asserts what the CHECK verifies,
# because that is what an assessor runs.
{
  pkgs,
  lib,
}: let
  # A VM small enough to boot quickly, with nothing enabled that a control is asserting.
  baseNode = {
    boot.loader.grub.enable = false;
    documentation.enable = false;
    system.stateVersion = "25.05";
  };
in rec {
  # One spec -> one test derivation.
  mkTest = spec:
    pkgs.testers.runNixOSTest {
      name = "stig-${spec.id}";

      nodes.machine = {...}: {
        imports = spec.modules ++ [baseNode] ++ (spec.extraModules or []);
      };

      # The spec's description is deliberately NOT passed through as `meta.description`:
      # runNixOSTest's meta submodule does not declare that option and rejects it. It is
      # carried in the spec for the report and the gate output instead.
      testScript = ''
        # ${spec.id}: ${spec.description}
        machine.wait_for_unit("multi-user.target")
        ${spec.script}
      '';
    };

  # Many specs -> { "stig-V-268141" = <drv>; ... }
  mkTests = specs:
    builtins.listToAttrs (map (spec: {
        name = "stig-${spec.id}";
        value = mkTest spec;
      })
      specs);

  # Shape validation, used by the colocated suites so a malformed spec is caught at eval
  # rather than after a VM has booted.
  specProblems = spec:
    lib.optional (!(spec ? id) || builtins.match "V-[0-9]+" spec.id == null)
    "id must look like V-nnnnnn"
    ++ lib.optional (!(spec ? description) || spec.description == "")
    "${spec.id or "?"}: description must be a non-empty sentence"
    ++ lib.optional (!(spec ? modules) || !builtins.isList spec.modules)
    "${spec.id or "?"}: modules must be a list"
    ++ lib.optional (!(spec ? script) || builtins.stringLength spec.script < 20)
    "${spec.id or "?"}: script must actually assert something"
    # A script with no assertion is a test that cannot fail.
    ++ lib.optional ((spec ? script) && builtins.match ".*machine\\.(succeed|fail|wait_for_unit|wait_until_succeeds).*" spec.script == null)
    "${spec.id or "?"}: script must call machine.succeed/fail/wait_*";
}
