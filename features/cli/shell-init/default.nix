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
# The same directory is also where the upstream nu_scripts completers land. Those are
# `extern` declarations — hand-written Nushell signatures for git, nix, make and friends — and
# they are copied out of the pinned `nu-scripts` flake input at build time rather than
# vendored into this repo, for the same reason the `init` output is generated rather than
# committed: a copy drifts from its source.
#
# Usage: importing the feature enables it. To drop a hook on a host:
#   cli.shellInit.hooks = ["env" "starship"];
# To take a completer the default set leaves out:
#   cli.shellInit.completers = ["git" "make" "nix" "cargo"];
{
  config,
  inputs,
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

  # ---------------------------------------------------------------------------
  # Completer table — upstream nu_scripts, copied out of the flake input
  # ---------------------------------------------------------------------------
  #
  # The 5x prefixes put these *after* `30-carapace.nu`, and the reason is not precedence.
  # Precedence is settled by the parser rather than by load order: an `extern` gives the
  # command a known signature, and `completions.external.completer` — carapace — is only
  # consulted for commands whose signature Nushell does not know. Sourcing
  # git-completions.nu before or after the carapace init completes `git sw` to `git switch`
  # either way, which is measured, not assumed. So for every command covered here the
  # hand-written Nu completer wins, and carapace keeps everything else.
  #
  # What the order does decide is blast radius. These are by far the largest files in the
  # directory and the ones most likely to break: nu_scripts tracks Nushell's language closely
  # and this repo bumps the input on its own schedule. Loading last means a bad bump costs
  # completions and nothing else — the prompt, `cd`, the external completer and history are
  # all in place by the time Nushell reaches 50. Ahead of carapace the same failure would sit
  # in front of the things a shell is unusable without.
  #
  # Prefixes are alphabetical rather than ordered by the default set, so a host opting cargo
  # or docker in does not renumber anything.
  completers = {
    cargo = {
      filename = "50-cargo-completions.nu";
      path = "custom-completions/cargo/cargo-completions.nu";
    };
    docker = {
      filename = "51-docker-completions.nu";
      path = "custom-completions/docker/docker-completions.nu";
    };
    git = {
      filename = "52-git-completions.nu";
      path = "custom-completions/git/git-completions.nu";
    };
    make = {
      filename = "53-make-completions.nu";
      path = "custom-completions/make/make-completions.nu";
    };
    nix = {
      filename = "54-nix-completions.nu";
      path = "custom-completions/nix/nix-completions.nu";
    };
  };

  completerNames = ["cargo" "docker" "git" "make" "nix"];

  # Measured on drakkar as the `source` cost of each file over a bare `nu` (hyperfine, 300+
  # runs): cargo +1.3 ms, docker +1.6 ms, git +3.6 ms, make +0.5 ms, nix +2.0 ms. All five
  # together are +8.6 ms, which is the entire remaining headroom under the 35 ms interactive
  # startup budget; these three are +5.8 ms and leave some. cargo and docker stay selectable
  # and off — the two commands whose carapace specs are least often the weaker answer.
  defaultCompleters = ["git" "make" "nix"];

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

  emitCompleter = name: let
    completer = completers.${name};
  in "cp ${inputs.nu-scripts}/${completer.path} $out/${completer.filename}";

  autoload = pkgs.runCommand "nushell-vendor-autoload" {} ''
    scratch="$TMPDIR/scratch-home"
    mkdir -p "$scratch" $out
    ${concatMapStringsSep "\n" emit cfg.hooks}
    ${concatMapStringsSep "\n" emitCompleter cfg.completers}

    # Every file in here is sourced by every interactive shell, on the REPL path only, so a
    # file that does not parse prints its error on every shell start and nowhere else — not in
    # `nu -c`, not in CI, not in a script. The nu_scripts completers are the ones that will
    # eventually hit this: they are written against whatever Nushell release upstream had, and
    # the language moves. nu-check at build time turns the next such bump into a failed build.
    for f in $out/*.nu; do
      if ! HOME="$scratch" ${pkgs.nushell}/bin/nu --no-config-file \
        --commands "exit (if (nu-check '$f') { 0 } else { 1 })"; then
        echo "shell-init: $f does not parse under nushell ${pkgs.nushell.version}" >&2
        exit 1
      fi
    done

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
      mkEnableOption "generated Nushell vendor autoload (session variables, starship, zoxide, carapace, atuin, nu_scripts completers)"
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

    # A second list rather than five more entries in `hooks`: these are copies of a pinned
    # source, not the output of a command, and they answer a different question (which
    # commands get hand-written completions) from the one `hooks` answers (which tools get to
    # install themselves into the shell). Keeping them apart also means the startup budget
    # has one knob that is safe to turn down.
    completers = mkOption {
      type = types.listOf (types.enum completerNames);
      default = defaultCompleters;
      description = ''
        Which upstream nu_scripts custom completers to copy into
        `$nu.data-dir/vendor/autoload`. These are `extern` declarations, so they beat carapace
        for the commands they cover whatever the load order; the numeric prefix selects
        nothing but the order of the files.

        The default leaves cargo and docker out on startup budget, not on quality — see the
        per-file costs in the completer table.
      '';
      example = ["git" "nix"];
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
