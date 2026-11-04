# Generated shell init — Nushell's vendor autoload directory.
#
# Nushell sources every `.nu` file in `$nu.data-dir/vendor/autoload` at startup, in filename
# order, after `env.nu` and `config.nu` and only on the REPL path. That makes it the one hook in
# the shell that can carry *generated* content, which is where the `init` output of
# starship/zoxide/carapace/atuin belongs: produced at build time from the exact store path the
# host installs, never committed. `features/cli/nushell/starship.nu` was a committed copy of
# `starship init nu`, and a committed copy drifts from the binary it came from the moment either
# one moves.
#
# Running the four `init` commands at *build* time rather than per shell start is also the
# cheap way round: on drakkar they cost 2.1 / 0.9 / 3.7 / 8.7 ms respectively — 15 ms that the
# usual `init | source` in config.nu would pay on every shell start instead of once per
# generation.
#
# The same directory carries `environment.sessionVariables`. NixOS delivers those through
# /etc/set-environment (POSIX login shells only) and /etc/pam/environment (pam sessions only).
# Nushell reads neither, which is what `features/cli/nushell/login.nu`'s
# `bash --login -c "env -0"` round-trip existed to paper over — a subprocess on every login
# shell, replaced here by a file the shell already reads.
#
# Usage: importing the feature enables it. To drop a hook on a host:
#   cli.shellInit.hooks = ["env" "starship"];
{
  config,
  lib,
  pkgs,
  settings,
  ...
}:
with lib; let
  cfg = config.cli.shellInit;

  nushellDataDir = "${settings.userdir}/.local/share/nushell";
  autoloadDir = "${nushellDataDir}/vendor/autoload";

  # ---------------------------------------------------------------------------
  # 00-nixos-env.nu — environment.sessionVariables as Nu assignments
  # ---------------------------------------------------------------------------
  envFile = pkgs.writeText "00-nixos-env.nu" (import ./nu-env.nix {
    inherit lib;
    inherit (config.environment) sessionVariables;

    # NixOS appends profile-relative entries to these names when it writes
    # /etc/set-environment and /etc/pam/environment: XDG_DATA_DIRS gains
    # /run/current-system/sw/share, PATH gains /run/current-system/sw/bin, and so on.
    # Restating the bare `sessionVariables` value in Nu would *drop* those suffixes — and in
    # the XDG_DATA_DIRS case that silently removes most of this very directory's siblings,
    # since Nushell derives `$nu.vendor-autoload-dirs` from XDG_DATA_DIRS.
    reservedNames = ["PATH"] ++ attrNames config.environment.profileRelativeSessionVariables;
  });

  # ---------------------------------------------------------------------------
  # Hook table — the filename prefix IS the load order
  # ---------------------------------------------------------------------------
  #
  # `home` is the HOME each `init` runs under. It defaults to a scratch directory because
  # starship wants a log directory and atuin wants ~/.atuin before either will print anything,
  # and the sandbox HOME is the unwritable /homeless-shelter. carapace is the exception: it
  # bakes `$HOME/.config/carapace/bin` — its user-macro directory — straight into the PATH line
  # it emits, so a scratch HOME there would have every shell prepend the build sandbox's /build
  # to PATH. It gets the real home instead.
  hooks = {
    env = {
      filename = "00-nixos-env.nu";
      source = envFile;
    };
    starship = {
      filename = "10-starship.nu";
      command = "${pkgs.starship}/bin/starship init nu";
    };
    zoxide = {
      filename = "20-zoxide.nu";
      command = "${pkgs.zoxide}/bin/zoxide init nushell --cmd cd";
    };
    carapace = {
      filename = "30-carapace.nu";
      command = "${pkgs.carapace}/bin/carapace _carapace nushell";
      home = settings.userdir;
    };
    atuin = {
      filename = "40-atuin.nu";
      command = "${pkgs.atuin}/bin/atuin init nu";
    };
  };

  hookNames = ["env" "starship" "zoxide" "carapace" "atuin"];

  emit = name: let
    hook = hooks.${name};
  in
    if hook ? source
    then "cp ${hook.source} $out/${hook.filename}"
    else ''
      HOME=${hook.home or "$scratch"} ${hook.command} > $out/${hook.filename}
      # An init that prints nothing means the tool renamed its subcommand. Fail the build,
      # where it is visible, rather than the shell, where it is a missing prompt.
      test -s $out/${hook.filename}
    '';

  autoload = pkgs.runCommand "nushell-vendor-autoload" {} ''
    scratch="$TMPDIR/scratch-home"
    mkdir -p "$scratch" $out
    ${concatMapStringsSep "\n" emit cfg.hooks}

    # The scratch HOME must not reach a file that gets sourced on a real machine. This caught
    # carapace once; the next tool to bake $HOME into its init output should fail here rather
    # than quietly put a build path on somebody's PATH.
    if grep -rl -- "$TMPDIR" $out; then
      echo "shell-init: the file(s) above leaked the build sandbox path $TMPDIR" >&2
      exit 1
    fi
  '';
in {
  options.cli.shellInit = {
    # features/fleet/keepalived defaults its enable to false because hosts opt into a VIP one
    # at a time. This feature is imported by profiles/cli-core.nix for every host, so the
    # import is the opt-in and the default is on.
    enable =
      mkEnableOption "generated Nushell vendor autoload (session variables, starship, zoxide, carapace, atuin)"
      // {default = true;};

    hooks = mkOption {
      type = types.listOf (types.enum hookNames);
      default = hookNames;
      description = ''
        Which init hooks to generate into `$nu.data-dir/vendor/autoload`. The numeric filename
        prefix fixes the load order, so this list selects; it does not reorder.
      '';
      example = ["env" "starship"];
    };
  };

  config = mkMerge [
    # Relocated from features/cli/fish/default.nix, where this block had lived since fish was
    # the login shell. `environment.sessionVariables` is a global attribute with nothing
    # shell-specific about it, and the shell that now needs the most help reaching it is
    # nushell, not fish — so it belongs with the feature that carries it into shells rather
    # than with one consumer. Declared outside the `enable` gate: these variables are the
    # host's, not this generator's.
    {
      environment.sessionVariables = {
        EDITOR = "nvim";
        GIT_EDITOR = "nvim";
        DIFFPROG = "nvim -d";
        XDG_CACHE_HOME = "$HOME/.cache";
        XDG_CONFIG_HOME = "$HOME/.config";
        XDG_DATA_HOME = "$HOME/.local/share";
        XDG_STATE_HOME = "$HOME/.local/state";
      };
    }

    (mkIf cfg.enable {
      # The whole directory is one symlink into the store rather than a file-by-file copy:
      # dropping a hook from `hooks` then takes its file with it. A copy leaves the dropped
      # file behind and Nushell keeps sourcing it on every start, which is the
      # stale-generated-file failure this feature exists to end.
      system.activationScripts.nushellVendorAutoload = {
        text = ''
          install -d -o ${settings.username} -g users -m 0755 \
            ${settings.userdir}/.local \
            ${settings.userdir}/.local/share \
            ${nushellDataDir} \
            ${nushellDataDir}/vendor

          if [ -e ${autoloadDir} ] && [ ! -L ${autoloadDir} ]; then
            rm -rf ${autoloadDir}.backup
            mv ${autoloadDir} ${autoloadDir}.backup
          fi
          ln -sfn ${autoload} ${autoloadDir}
          chown -h ${settings.username}:users ${autoloadDir}
        '';
      };
    })
  ];
}
