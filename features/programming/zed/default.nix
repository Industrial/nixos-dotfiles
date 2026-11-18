# Zed — native GPU-accelerated editor, the middle option between Cursor's Electron
# tree and features/programming/helix's single terminal process.
#
# Rust and GPUI rather than a browser engine, so it is genuinely lighter than
# Cursor while still being a windowed editor with a familiar shape — buffers, a
# project panel, a settings UI. If the goal is "Cursor, but it stops eating the
# machine", this is the candidate to actually live in for a week; Helix is the one
# to reach for when even that is more than the task needs.
#
# THREE THINGS ARE NIXOS-SPECIFIC HERE, and each is why this file exists rather
# than a one-line systemPackages entry.
#
# 1. ZED DOWNLOADS LANGUAGE SERVERS. Upstream: "Language servers are automatically
#    downloaded or launched if found in your path." The downloaded ones are generic
#    glibc binaries, so on NixOS they hit stub-ld and die with the familiar "NixOS
#    cannot run dynamically linked executables intended for generic linux
#    environments" — reported back as a server that just never comes up.
#    features/ai/cloudcli documents the same class of failure from the other side.
#    Every server Zed is allowed to use is therefore pinned to a nixpkgs path with
#    `binary.ignore_system_version = false` plus an explicit `path`, and the
#    binaries are in systemPackages so those paths resolve.
#
# 2. SAME REASON, FOR NODE. Zed fetches its own Node to host several servers.
#    `node.path`/`npm_path` point at the nixpkgs build and `ignore_system_version`
#    stays false, so nothing is downloaded and nothing hits stub-ld.
#
# 3. load_direnv STAYS "direct", AND THIS IS DELIBERATE. Zed's own migration guide
#    recommends "shell_hook", which is wrong for this fleet: the hook option
#    supports POSIX shells and fish, and the login shell here is nushell
#    (/run/current-system/sw/bin/nu). "direct" runs `direnv export json` instead
#    and is shell-agnostic, which is what makes Zed see the devenv environment —
#    the thing that actually matters, since this repo's toolchains live in
#    devenv shells rather than on the global PATH.
#
# RUST GETS NO LANGUAGE SERVER, for the reason recorded in
# features/programming/helix and in ~/.claude/CLAUDE.md: three stray
# rust-analyzer instances measured 4.8 GB on this machine and contributed to OOM
# kills on a 61 GB box. Asking for a lighter editor and then letting it spawn the
# heaviest process in the fleet per project would defeat the exercise, so
# `enable_language_server` is false for Rust and rust-analyzer is not installed.
#
# CONFIG IS SEEDED, NOT SYMLINKED — the opposite of features/programming/helix,
# and the asymmetry is the point. Zed's settings UI writes settings.json back to
# disk, and a symlink into the read-only store would make the UI fail on save.
# Helix never writes its config, so there a store symlink is free. Here the file
# is installed once if absent and then belongs to you; `switch` will not touch it
# again. To pick up a changed default, move your copy aside and switch.
{
  pkgs,
  settings,
  ...
}: let
  configDir = "${settings.userdir}/.config/zed";

  # *Bin suffixes are load-bearing, not style. `environment.systemPackages` below
  # is written `with pkgs; [...]`, and a `let` binding outranks a `with` scope — so
  # naming these `nixd`/`taplo`/`ruff` shadowed the packages of the same name and
  # put bare path strings into systemPackages instead of derivations. The
  # colocated suite caught it; the suffix is what keeps it caught.
  nixdBin = "${pkgs.nixd}/bin/nixd";
  taploBin = "${pkgs.taplo}/bin/taplo";
  ruffBin = "${pkgs.ruff}/bin/ruff";
  alejandraBin = "${pkgs.alejandra}/bin/alejandra";
  nodeBin = "${pkgs.nodejs_22}/bin/node";
  npmBin = "${pkgs.nodejs_22}/bin/npm";

  zedSettings = {
    telemetry = {
      diagnostics = false;
      metrics = false;
    };

    # See note 3 in the header: "direct", not "shell_hook", because nushell.
    load_direnv = "direct";

    # See note 2: never fetch a Node.
    node = {
      ignore_system_version = false;
      path = nodeBin;
      npm_path = npmBin;
    };

    # See note 1: every server pinned to the store.
    lsp = {
      nixd.binary.path = nixdBin;
      taplo.binary.path = taploBin;
      ruff.binary.path = ruffBin;
    };

    languages = {
      # The RAM decision. Tree-sitter highlighting still works; completion,
      # diagnostics and go-to-definition do not. That is the trade being made.
      Rust = {
        enable_language_server = false;
        show_edit_predictions = false;
      };

      Nix = {
        language_servers = ["nixd"];
        formatter = {
          external = {
            command = alejandraBin;
            arguments = ["--quiet" "-"];
          };
        };
        format_on_save = "on";
      };

      TOML.language_servers = ["taplo"];
      Python.language_servers = ["ruff"];
    };

    # Nothing in this repo is wired to a Zed-hosted model, and leaving the
    # provider unset means the panel does not prompt for credentials on open.
    # Claude Code stays the agent surface — see features/ai/claude-code.
    #
    # `edit_predictions.provider`, NOT `features.edit_prediction_provider`. The
    # latter is what the first version of this file shipped, and Zed 1.28.1 flags
    # it with "Your settings file uses deprecated settings"; the binary carries a
    # migrate_edit_prediction_provider_to_edit_predictions transform for exactly
    # this rename. Checked against the installed binary rather than the docs,
    # which describe `main` — see the note on relative_line_numbers below.
    edit_predictions.provider = "none";

    vim_mode = false;
    buffer_font_family = "Zed Plex Mono";
    ui_font_size = 16;
    buffer_font_size = 14;
    # A boolean, pinned to the installed version on purpose. Zed's docs on `main`
    # document this as the string enum "enabled"/"disabled", but 1.28.1 still
    # carries the assertion "Expected relative_line_numbers to be a boolean" — so
    # taking the published docs at face value here would have broken a setting
    # that currently works. Revisit when zed-editor in nixpkgs crosses that
    # change; until then the docs and this file disagree for a reason.
    relative_line_numbers = true;
    format_on_save = "on";
    terminal.shell = "system";
  };

  settingsFile = pkgs.writeText "zed-settings.json" (builtins.toJSON zedSettings);
in {
  environment.systemPackages = with pkgs; [
    zed-editor

    # The servers the settings above pin by path. These are the same tools
    # features/programming/helix installs, so the two editors format identically
    # and neither fights treefmt.
    nixd
    alejandra
    taplo
    ruff
    nodejs_22
  ];

  system.activationScripts.zedSettingsSeed = {
    text = ''
      install -d -o ${settings.username} -g users -m 0755 ${configDir}

      # Seed once. Zed's settings UI owns this file afterwards — re-copying on
      # every switch would silently revert whatever you changed in the UI, the
      # same trap features/cli/tealdeer avoids with its page cache.
      if [ ! -e ${configDir}/settings.json ]; then
        echo "zed: seeding ${configDir}/settings.json (yours to edit from here on)"
        install -o ${settings.username} -g users -m 0644 \
          ${settingsFile} ${configDir}/settings.json
      fi
    '';
  };
}
