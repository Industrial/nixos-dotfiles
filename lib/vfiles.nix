# vfiles: declared user files, placed by rust/tools/vfiles (GH-188).
#
# A feature that puts a file in someone's home declares it here instead of writing an
# activation script for it:
#
#   imports = [../../../lib/vfiles.nix];
#   vfiles.files."${settings.userdir}/.config/foo/foo.toml" = {
#     source = ./foo.toml;          # or `text = ''…'';`
#     user = settings.username;
#   };
#
# and keeps its pre-vfiles script, for the rollback, under `vfiles.legacy.<name>`.
#
# This module is imported by every feature that declares a file (and by
# features/nixos/vfiles), from outside features/, so lib/features.nix passes it through
# unconditionally: the options exist on every host, and nothing here is active until
# `vfiles.enable` is set.
#
#   vfiles.enable = true  (features.nixos.vfiles.enable): one activation step,
#     `vfiles --spec <spec> --state-dir /var/lib/vfiles`, places every declared file.
#     With userborn (services.userborn), whose unit writes /etc/passwd after the activation
#     on boot, that step skips itself while an owner is missing (a fresh install's first
#     boot, a switch adding a user) and vfiles.service, ordered after userborn.service,
#     runs the same command (GH-205).
#   vfiles.enable = false (the default): the features' legacy scripts run, as before.
#
# Rollback on a host: `features.nixos.vfiles.enable = lib.mkForce false;`. The legacy
# scripts come back (they back up and replace what vfiles placed, as they always did).
#
# What vfiles does with each file (see rust/tools/vfiles/src/plan.vlt):
#   - places it atomically, owned by `user`:`group`, making missing parent directories
#     owned by the same user;
#   - records it in /var/lib/vfiles/manifest.json and, once a file leaves the spec,
#     removes it if it is still as vfiles left it;
#   - on the first run, a real file already there is moved to `<name>.backup` and taken
#     over; a symlink there (the legacy scripts' links) is simply replaced;
#   - after that, a file edited by hand is reported (drift) and never overwritten,
#     unless `force` is set;
#   - writes /var/lib/vfiles/report.json and warns on stderr (the switch output).
#
# Health probe: `vfiles --dry-run --spec /etc/vfiles/spec.json | jq '.failed, .drift'`.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.vfiles;

  sourceType = types.oneOf [types.path types.package types.str];

  fileModule = {name, ...}: {
    options = {
      path = mkOption {
        type = types.str;
        default = name;
        description = "Absolute path of the file. Defaults to the attribute name.";
      };
      source = mkOption {
        type = types.nullOr sourceType;
        default = null;
        description = ''
          What to place: a Nix path or store path (copied into the store), or an absolute
          out-of-store path such as the ~/.dotfiles checkout, linked as is.
        '';
      };
      text = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "The file's content, written to the store. Alternative to `source`.";
      };
      fallback = mkOption {
        type = types.nullOr sourceType;
        default = null;
        description = "Placed instead of `source` while `source` does not exist (an out-of-store checkout that is missing).";
      };
      mode = mkOption {
        type = types.enum ["link" "copy" "seed" "absent"];
        default = "link";
        description = ''
          link: a symlink to the source. copy: a copy, replaced when the source changes.
          seed: a copy placed only when nothing is there; the user's from then on.
          absent: nothing; a stray symlink is removed, a real file is reported.
        '';
      };
      user = mkOption {
        type = types.str;
        description = "Owner of the file and of any parent directory vfiles makes.";
      };
      group = mkOption {
        type = types.str;
        default = "users";
        description = "Group of the file and of any parent directory vfiles makes.";
      };
      perms = mkOption {
        type = types.strMatching "0?[0-7]{3}";
        default = "0644";
        description = "Mode of a copied file (copy, seed).";
      };
      immutable = mkOption {
        type = types.bool;
        default = false;
        description = "Set the immutable attribute (chattr +i) on a copied file, so a program cannot replace it.";
      };
      force = mkOption {
        type = types.bool;
        default = false;
        description = "Replace the file even when it changed since vfiles placed it: for files their program rewrites (btop.conf).";
      };
    };
  };

  # A Nix path is copied into the store, a package is its out path, and a string (a store
  # path, or an out-of-store path) stays what it says.
  stored = s: "${s}";

  sourceOf = f:
    if f.text != null
    then "${pkgs.writeText (baseNameOf f.path) f.text}"
    else if f.source != null
    then stored f.source
    else null;

  entry = f: {
    inherit (f) path mode user group perms immutable force;
    source = sourceOf f;
    fallback =
      if f.fallback == null
      then null
      else stored f.fallback;
  };

  files = lib.attrValues cfg.files;

  spec = pkgs.writeText "vfiles-spec.json" (builtins.toJSON {
    version = 1;
    files = map entry (lib.sortOn (f: f.path) files);
  });

  run = "${cfg.package}/bin/vfiles --spec ${spec} --state-dir /var/lib/vfiles";

  # Under userborn the activation step may have to wait for the owners (GH-205).
  userborn = config.services.userborn.enable or false;
  owners = {
    users = lib.unique (lib.sort lib.lessThan (map (f: f.user) files));
    groups = lib.unique (lib.sort lib.lessThan (map (f: f.group) files));
  };
in {
  options.vfiles = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Place `vfiles.files` with vfiles. Set by features.nixos.vfiles; while off, the
        legacy activation scripts in `vfiles.legacy` run instead.
      '';
    };

    files = mkOption {
      type = types.attrsOf (types.submodule fileModule);
      default = {};
      description = "Files to place in users' homes, by absolute path.";
    };

    legacy = mkOption {
      type = types.attrsOf types.unspecified;
      default = {};
      description = ''
        The activation scripts the declared files replaced, by name: they become
        `system.activationScripts` while `vfiles.enable` is off (the rollback).
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../rust/tools/vfiles/default.nix {};
      defaultText = lib.literalExpression "pkgs.callPackage ../rust/tools/vfiles/default.nix {}";
      description = "The vfiles package.";
    };

    spec = mkOption {
      type = types.package;
      readOnly = true;
      internal = true;
      default = spec;
      description = "The spec vfiles is run with.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (!cfg.enable) {
      system.activationScripts = cfg.legacy;
    })

    (lib.mkIf cfg.enable {
      assertions =
        map (f: {
          assertion = lib.hasPrefix "/" f.path;
          message = "vfiles.files.\"${f.path}\": the path must be absolute.";
        })
        files
        ++ map (f: {
          assertion =
            if f.mode == "absent"
            then f.source == null && f.text == null
            else (f.source == null) != (f.text == null);
          message = "vfiles.files.\"${f.path}\": set exactly one of source and text (neither, for mode absent).";
        })
        files;

      environment.systemPackages = [cfg.package];
      environment.etc."vfiles/spec.json".source = spec;

      # After the users and groups exist; nothing else: every source is a store path or an
      # out-of-store path vfiles checks itself.
      system.activationScripts.vfiles = {
        deps = ["users" "groups"];
        text =
          if userborn
          then ''
            # userborn (GH-205): on a fresh install's first boot the activation runs before
            # userborn.service has written /etc/passwd and /etc/group, and so before the
            # owners exist. Defer to vfiles.service, which runs once userborn has.
            vfiles_missing=""
            for u in ${lib.escapeShellArgs owners.users}; do
              grep -q "^$u:" /etc/passwd 2>/dev/null || vfiles_missing="$vfiles_missing user:$u"
            done
            for g in ${lib.escapeShellArgs owners.groups}; do
              grep -q "^$g:" /etc/group 2>/dev/null || vfiles_missing="$vfiles_missing group:$g"
            done
            if [ -n "$vfiles_missing" ]; then
              echo "vfiles: deferred to vfiles.service, not yet in the user database:$vfiles_missing" >&2
            else
              ${run}
            fi
          ''
          else ''
            ${run}
          '';
      };

      # The run after userborn: on boot, and again on a switch that changes the spec (a new
      # user's files, which the activation step deferred). Where the activation step already
      # placed everything, this second run finds every file kept, and changes nothing.
      systemd.services.vfiles = lib.mkIf userborn {
        description = "Place the declared user files once userborn has written the users (GH-205)";
        after = ["userborn.service"];
        requires = ["userborn.service"];
        wantedBy = ["multi-user.target"];
        restartTriggers = [spec];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${run}
        '';
      };
    })
  ];
}
