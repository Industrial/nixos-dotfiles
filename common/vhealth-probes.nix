# The `features.nix.vhealth.probes.<name>` option: health probes, declared by the feature
# that owns the service and run by features/nix/vhealth (rust/tools/vhealth).
#
# Options only, no config. features/nix/vhealth imports it, so the option exists on every
# host (lib/features.nix keeps a feature's options whether it is enabled or not), and a
# feature that declares a probe imports it too, so the feature still evaluates on its own
# (its colocated assay suite). The module system evaluates it once however many import it.
#
#   imports = [../../../common/vhealth-probes.nix];
#   features.nix.vhealth.probes.vcache = {
#     type = "http";
#     url = "http://${bindIp}:${toString port}/nix-cache-info";
#     bodyContains = "StoreDir: /nix/store";
#   };
#
# Types and the fields each needs: tcp (host, port), http (url; status, bodyContains), unix
# (path), command (argv, no shell, must exit 0), file (path, maxAge in seconds). Addresses
# come from common/fleet.nix, not literals.
{lib, ...}: let
  inherit (lib) mkOption types;

  probe = types.submodule {
    options = {
      type = mkOption {
        type = types.enum ["tcp" "http" "unix" "command" "file"];
        description = "What the probe checks: a TCP connect, an HTTP GET, a unix socket connect, a command's exit, a file's age.";
      };
      description = mkOption {
        type = types.str;
        default = "";
        description = "What the probe says about the service, for people.";
      };
      host = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "tcp: the host to connect to (an address from common/fleet.nix, not a literal).";
      };
      port = mkOption {
        type = types.nullOr types.port;
        default = null;
        description = "tcp: the port to connect to.";
      };
      url = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "http: the http:// URL to GET.";
      };
      status = mkOption {
        type = types.ints.between 100 599;
        default = 200;
        description = "http: the status the answer must have.";
      };
      bodyContains = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "http: text the body must contain.";
      };
      path = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "unix: the socket; file: the file.";
      };
      argv = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "command: the program and its arguments (no shell); it must exit 0.";
      };
      maxAge = mkOption {
        type = types.nullOr types.ints.unsigned;
        default = null;
        description = "file: the most seconds since the file was modified.";
      };
      timeout = mkOption {
        type = types.ints.positive;
        default = 5000;
        description = "Milliseconds the probe may take before it is down.";
      };
      critical = mkOption {
        type = types.bool;
        default = true;
        description = "Whether this probe being down makes the host unhealthy (and a deploy roll back).";
      };
    };
  };
in {
  options.features.nix.vhealth.probes = mkOption {
    type = types.attrsOf probe;
    default = {};
    description = "Health probes, by name. Declared by the feature that owns the service; run by vhealth where features.nix.vhealth is enabled.";
  };
}
