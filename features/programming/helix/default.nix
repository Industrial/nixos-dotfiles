# Helix — modal editor, terminal-native, no runtime and no plugin host.
#
# WHY THIS IS HERE: Cursor's Electron process tree is the heaviest thing on these
# desktops, and this is the opposite end of the scale. Helix is a single Rust
# binary with tree-sitter built in; the only subprocesses it ever starts are the
# language servers you let it start, which is the whole point of languages.toml
# below. Compare features/programming/zed for the middle option — native and
# GPU-accelerated, but still a windowed application with its own process tree.
#
# THE RAM BUDGET IS THE FEATURE, so the language-server list is a deny-list, not an
# afterthought. ~/.claude/CLAUDE.md records why: three stray rust-analyzer
# instances were measured at 4.8 GB on this machine, none of them an editor's, two
# more than a day old, and they contributed to a stream of OOM kills on a 61 GB
# box. rust-analyzer-lsp is disabled in the Claude harness for exactly that
# reason. An editor that silently spawns one per project would reintroduce the
# problem through a different door, so Rust gets `language-servers = []` and
# rust-analyzer is deliberately absent from systemPackages.
#
# That is a real trade and worth naming: Rust files open with tree-sitter
# highlighting and no completion, no go-to-definition and no diagnostics. For Rust
# work that needs those, `roam_search_symbol` answers the structural questions
# (see rules/roam-code.md) and `cargo check` answers the rest, at a fraction of
# the resident cost.
#
# CONFIG IS A STORE SYMLINK, not a seeded copy, following features/cli/atuin.
# Helix only ever reads these files — nothing in the editor
# writes its own config back — so an immutable symlink costs nothing and keeps the
# configuration reviewable here instead of drifting in $HOME. A pre-existing real
# file is moved aside rather than clobbered. features/programming/zed goes the
# other way for the opposite reason; the comment there explains it.
{
  pkgs,
  settings,
  ...
}: let
  configDir = "${settings.userdir}/.config/helix";

  configFile = pkgs.writeText "helix-config.toml" ''
    # Managed by features/programming/helix. Edits here are overwritten on switch.
    theme = "base16_transparent"

    [editor]
    line-number = "relative"
    bufferline = "multiple"
    color-modes = true
    cursorline = true
    true-color = true
    # Helix defaults to scanning for a workspace root; keep it quiet in big trees.
    completion-timeout = 250

    [editor.statusline]
    left = ["mode", "spinner", "version-control", "file-name"]
    right = ["diagnostics", "selections", "position", "file-encoding", "file-type"]

    [editor.lsp]
    display-messages = true
    # Inlay hints are a per-keystroke round trip to every attached server. Off by
    # default here; `:toggle lsp.display-inlay-hints` turns them on per session.
    display-inlay-hints = false

    [editor.cursor-shape]
    insert = "bar"
    normal = "block"
    select = "underline"

    [editor.indent-guides]
    render = true

    [editor.file-picker]
    hidden = false

    [editor.soft-wrap]
    enable = true
  '';

  languagesFile = pkgs.writeText "helix-languages.toml" ''
    # Managed by features/programming/helix. Edits here are overwritten on switch.

    # Rust: no language server, on purpose. See the header comment in default.nix —
    # rust-analyzer is the single largest memory consumer this fleet has measured,
    # and it is absent from systemPackages so this is belt and braces.
    [[language]]
    name = "rust"
    language-servers = []
    auto-format = false

    # Nix: nixd for analysis, alejandra for formatting — the same pair
    # features/programming/cursor installs, so both editors agree on format output
    # and treefmt does not fight whichever one you used.
    [[language]]
    name = "nix"
    language-servers = ["nixd"]
    formatter = { command = "alejandra", args = ["--quiet", "-"] }
    auto-format = true

    [language-server.nixd]
    command = "nixd"

    [[language]]
    name = "toml"
    language-servers = ["taplo"]
    auto-format = true

    [[language]]
    name = "python"
    language-servers = ["ruff"]
    auto-format = true

    [language-server.ruff]
    command = "ruff"
    args = ["server"]
  '';
in {
  environment.systemPackages = with pkgs; [
    helix

    # The servers named in languages.toml, and nothing beyond them. Helix attaches
    # only what it is told to, so anything added here without a languages.toml
    # entry is dead weight — and anything in languages.toml without an entry here
    # is a silent "no server for this language".
    nixd
    alejandra
    taplo
    ruff
  ];

  # EDITOR is deliberately not set. profiles/* and the shell features own that, and
  # quietly repointing it from a feature import is the kind of change that is very
  # annoying to track down from the other side.

  imports = [../../../lib/vfiles.nix];

  vfiles.files = {
    "${configDir}/config.toml" = {
      source = configFile;
      user = settings.username;
    };
    "${configDir}/languages.toml" = {
      source = languagesFile;
      user = settings.username;
    };
  };

  # The pre-vfiles script, kept for the rollback (features.nixos.vfiles off, lib/vfiles.nix).
  vfiles.legacy.helixConfig = {
    text = ''
      install -d -o ${settings.username} -g users -m 0755 ${configDir}

      for name in config.toml languages.toml; do
        # Move a real file aside rather than clobber it, the same way
        # features/cli/atuin does.
        if [ -f ${configDir}/$name ] && [ ! -L ${configDir}/$name ]; then
          mv ${configDir}/$name ${configDir}/$name.backup
        fi
      done

      ln -sfn ${configFile} ${configDir}/config.toml
      ln -sfn ${languagesFile} ${configDir}/languages.toml
      chown -R ${settings.username}:users ${configDir}
    '';
  };
}
