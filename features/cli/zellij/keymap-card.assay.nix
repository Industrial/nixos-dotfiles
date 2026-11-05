# Colocated suite: the keymap card is a parse of config.kdl, not a transcription of it.
#
# The counts below are re-derived from config.kdl with regexes the generator does not share, so
# a generator that silently ignored its input — or quietly kept a stale copy — fails here rather
# than shipping a card that disagrees with the keymap.
let
  assay = import ./../../../common/assay/default.nix;

  card = import ./keymap-card.nix;
  kdl = builtins.readFile ./etc/zellij/config.kdl;

  inCard = pattern: builtins.match pattern card != null;

  # Only the `keybinds` block. `builtins.split` hands back [before [] after], so element 2 is
  # everything from the opening brace on; the blocks above it (`ui`, `plugins`, `load_plugins`)
  # open braces too and must not be counted as modes.
  keybindsBlock = builtins.elemAt (builtins.split "keybinds clear-defaults=true [{]" kdl) 2;
  blockLines = builtins.filter builtins.isString (builtins.split "\n" keybindsBlock);
  linesMatching = pattern: builtins.filter (line: builtins.match pattern line != null) blockLines;

  # `[[:space:]]+bind` requires `bind` to follow the indent directly, so `// bind "Alt y"` and
  # `//bind "Alt i"` are excluded exactly as the generator excludes them.
  bindLines = linesMatching "[[:space:]]+bind[[:space:]].*";
  modeLines = linesMatching "  [a-z_]+ [{]";
  sharedLines = linesMatching "  shared_except .*[{]";

  # Live lines only. The commented-out `shared_except "move" "locked"` block *does* contain the
  # string `SwitchToMode "move"`, so a whole-file grep for it answers the wrong question.
  liveLines = builtins.filter (line: builtins.match "[[:space:]]*//.*" line == null) blockLines;
  switchesToMove =
    builtins.filter (line: builtins.match ".*SwitchToMode \"move\".*" line != null) liveLines;

  # A row of the derived mode-graph table, matched on its middle column: the trailing backtick
  # is what distinguishes `| `move` |` as a destination from `| `move` |` as the block a bind
  # was declared in, which ends the row.
  entersMode = mode: inCard (".*[|] `" + mode + "` [|] `.*");
in
  assay.suite "zellij-keymap-card" {
    # Provenance, stated in the artifact itself: whoever finds /etc/zellij/keymap.md on a host
    # needs to know it is generated before they try to edit it.
    declaresItsSource =
      assay.eq (inCard ".*source:     features/cli/zellij/etc/zellij/config.kdl.*") true;
    declaresItsGenerator =
      assay.eq (inCard ".*generator:  features/cli/zellij/keymap-card.nix.*") true;

    # The three counts, each one re-derived above rather than read off the card.
    countsEveryBindLine =
      assay.eq (inCard (".*- `bind` lines: " + toString (builtins.length bindLines) + "\n.*")) true;
    countsEveryModeBlock =
      assay.eq (inCard (".*- mode blocks: " + toString (builtins.length modeLines) + "\n.*")) true;
    countsEverySharedBlock =
      assay.eq (inCard (".*- `shared_except` blocks: " + toString (builtins.length sharedLines) + "\n.*")) true;
    # Thirteen modes and eight shared blocks as of this config, restated so that a parser which
    # started dropping blocks and a config that genuinely lost one are told apart.
    thirteenModesAndEightSharedBlocks =
      assay.eq [(builtins.length modeLines) (builtins.length sharedLines)] [13 8];

    # Every block in config.kdl gets its own section, including `normal`, which binds nothing
    # because its only entry is commented out. A card that hid empty blocks would read as though
    # `normal` had keys of its own.
    everyModeHasASection =
      assay.eq (builtins.all (mode: inCard (".*### `" + mode + "`.*")) [
        "normal"
        "locked"
        "resize"
        "pane"
        "move"
        "tab"
        "scroll"
        "search"
        "entersearch"
        "renametab"
        "renamepane"
        "session"
        "tmux"
      ])
      true;
    normalBlockIsShownAsEmpty =
      assay.eq (inCard ".*### `normal`\n\nDeclared, binds nothing.*") true;

    # The tmux compatibility layer, behind `Alt b`, including the one key whose name is itself a
    # double quote (`bind "\"" { … }`) — the token that breaks any quote-splitting parser.
    carriesTheTmuxPrefix =
      assay.eq (inCard ".*[|] `Alt b` [|] `tmux` [|] `shared_except \"tmux\" \"locked\"` [|].*") true;
    carriesTheEscapedQuoteKey =
      assay.eq (inCard ".*[|] `\"` [|] `NewPane \"Down\"; SwitchToMode \"normal\"` [|].*") true;
    leaksNoSentinel = assay.eq (inCard ".*@@dq@@.*") false;

    # Commented-out binds are config.kdl's record of what it decided *not* to do. A card that
    # listed them would promise keys that do nothing.
    omitsCommentedCopyBind = assay.eq (inCard ".*Alt y.*") false;
    omitsCommentedMoveTabBinds = assay.eq (inCard ".*MoveTab.*") false;
    omitsCommentedSessionManagerBind = assay.eq (inCard ".*LaunchOrFocusPlugin.*") false;

    # The card reports this config, not zellij's manual. `Ctrl p`/`Ctrl t`/`Ctrl n`/`Ctrl s` are
    # zellij's own default mode keys and `clear-defaults=true` threw all of them away, so their
    # presence would mean the card had drifted towards upstream documentation.
    reportsNoZellijDefaultModeKeys =
      assay.eq (inCard ".*`Ctrl (p|t|n|s|o|h)`.*") false;

    # Locked mode, both directions, out of the derived mode graph rather than out of a comment.
    derivesLockedModeBothWays =
      assay.eq (inCard ".*[|] `Ctrl g` [|] `locked` [|] `shared_except \"locked\"` [|].*") true;
    derivesTheWayOutOfLockedMode =
      assay.eq (inCard ".*[|] `Ctrl g` [|] `normal` [|] `locked` [|].*") true;

    # Every mode with a pure mode-switch bind reaches the derived table. `renamepane` and
    # `entersearch` are absent on purpose: both are entered only by a compound action (`pane`'s
    # `c` and `scroll`'s `s`), so they appear in those blocks' tables instead.
    derivesAnEntryKeyForEveryPurelySwitchedMode =
      assay.eq (builtins.all entersMode [
        "normal"
        "locked"
        "pane"
        "resize"
        "scroll"
        "search"
        "session"
        "tab"
        "tmux"
        "renametab"
      ])
      true;
    compoundOnlyModesAreInTheirBlockTables =
      assay.eq (builtins.all (pattern: inCard pattern) [
        ".*[|] `c` [|] `SwitchToMode \"renamepane\"; PaneNameInput 0` [|].*"
        ".*[|] `s` [|] `SwitchToMode \"entersearch\"; SearchInput 0` [|].*"
      ])
      true;

    # Found by the card, recorded rather than fixed (docs/runbooks/terminal.md): `move` mode is
    # declared with seven binds and cannot be entered. `shared_except "move" "locked"` is
    # commented out in config.kdl and `Alt h` — the key it would have used — is bound to
    # `MoveFocusOrTab "Left"` in `shared_except "locked"`. Nothing switches to it anywhere.
    moveModeIsUnreachable = assay.eq (builtins.length switchesToMove) 0;
    cardShowsNoEntryKeyForMove = assay.eq (entersMode "move") false;
  }
