# The zellij keymap card — GENERATED from etc/zellij/config.kdl, never transcribed.
#
# config.kdl declares `keybinds clear-defaults=true`, so the keys it lists are the only keys
# zellij binds on this fleet: zellij's own documented defaults are gone, and zellij's built-in
# help still reports those defaults. That leaves the fleet's real keymap with no readable
# surface anywhere, which is what this file produces.
#
# It parses rather than copies. Wave 6 generated the four layouts with `writeTextFile` plus
# interpolation (see default.nix), and the help-cutover leaf deliberately refused to transcribe
# the keymap into a navi sheet — a transcription disagrees with its source the moment either one
# moves, and a keymap card that disagrees with the keymap is worse than no card. config.kdl
# stays the single source of truth; this is a view of it.
#
# This file evaluates to the markdown string itself rather than to a function or a module, so it
# is readable straight out of a checkout with no module system and no `lib`:
#
#   nix eval --raw -f features/cli/zellij/keymap-card.nix
#
# `builtins` only, for that reason. Note that `\{` is not a valid escape in Nix's regex dialect,
# so every brace below goes through a character class — same constraint as default.assay.nix.
let
  raw = builtins.readFile ./etc/zellij/config.kdl;

  # The tmux block binds `"` itself (`bind "\"" { NewPane "Down"; … }`), the one key name that
  # would break every quote-split below. Swap it for a sentinel before parsing and swap it back
  # when rendering.
  sentinel = "@@dq@@";
  text = builtins.replaceStrings ["\\\""] [sentinel] raw;

  lines = builtins.filter builtins.isString (builtins.split "\n" text);

  trim = s: let
    m = builtins.match "[[:space:]]*(.*[^[:space:]])[[:space:]]*" s;
  in
    if m == null
    then ""
    else builtins.head m;

  hasPrefix = prefix: s: builtins.substring 0 (builtins.stringLength prefix) s == prefix;

  # Every quoted token of a fragment, in order. A split on `"` alternates outside/inside, so the
  # inside tokens are the odd indices.
  quotedTokens = fragment: let
    segments = builtins.filter builtins.isString (builtins.split "\"" fragment);
  in
    builtins.filter (token: token != null) (builtins.genList
      (i:
        if builtins.bitAnd i 1 == 1
        then builtins.elemAt segments i
        else null)
      (builtins.length segments));

  # A line that opens a block and is not a `bind`. Inside `keybinds` that is exactly a mode name
  # or a `shared_except` clause.
  blockName = line: let
    m = builtins.match "([^{]*[^{[:space:]])[[:space:]]*[{].*" line;
  in
    if m == null
    then null
    else builtins.head m;

  dropTrailingSemicolons = s: let
    m = builtins.match "(.*[^;[:space:]])[;[:space:]]*" s;
  in
    if m == null
    then s
    else builtins.head m;

  # One pass over the file. Comment lines are dropped before anything else, so a commented-out
  # `bind` stays out of the card: it reports what zellij does, not what it nearly does. Nothing
  # before `keybinds` is considered either — `ui`, `plugins` and `load_plugins` open blocks too.
  parse =
    builtins.foldl' (
      acc: line: let
        t = trim line;
        bind = builtins.match "bind[[:space:]]+([^{]*)[{][[:space:]]*(.*)[}].*" t;
        name = blockName t;
      in
        if t == "" || hasPrefix "//" t
        then acc
        else if hasPrefix "keybinds" t
        then acc // {reached = true;}
        else if !acc.reached
        then acc
        else if hasPrefix "bind" t
        then
          if bind == null
          then acc
          else
            acc
            // {
              binds =
                acc.binds
                ++ [
                  {
                    inherit (acc) block;
                    keys = quotedTokens (builtins.elemAt bind 0);
                    action = dropTrailingSemicolons (trim (builtins.elemAt bind 1));
                  }
                ];
            }
        else if name == null
        then acc
        else
          acc
          // {
            block = name;
            blocks = acc.blocks ++ [name];
          }
    ) {
      reached = false;
      block = "";
      blocks = [];
      binds = [];
    }
    lines;

  modeBlocks = builtins.filter (block: !(hasPrefix "shared_except" block)) parse.blocks;
  sharedBlocks = builtins.filter (hasPrefix "shared_except") parse.blocks;

  keyCount = builtins.foldl' (n: b: n + builtins.length b.keys) 0 parse.binds;

  restore = builtins.replaceStrings [sentinel] ["\""];
  renderKeys = keys: builtins.concatStringsSep " / " (builtins.map (key: "`" + restore key + "`") keys);

  # The mode graph, derived: a bind counts only when switching mode is its *whole* action, which
  # `builtins.match` gives for free by anchoring.
  switchTarget = b: let
    m = builtins.match "SwitchToMode \"([a-z]+)\"" b.action;
  in
    if m == null
    then null
    else builtins.head m;

  switches = builtins.filter (b: switchTarget b != null) parse.binds;

  switchRows =
    builtins.map (b: "| " + renderKeys b.keys + " | `" + switchTarget b + "` | `" + b.block + "` |") switches;

  blockCard = block: let
    rows =
      builtins.map (b: "| " + renderKeys b.keys + " | `" + b.action + "` |")
      (builtins.filter (b: b.block == block) parse.binds);
  in
    if rows == []
    then "### `" + block + "`\n\nDeclared, binds nothing.\n"
    else
      "### `"
      + block
      + "`\n\n| Keys | Action |\n| --- | --- |\n"
      + builtins.concatStringsSep "\n" rows
      + "\n";
in
  builtins.concatStringsSep "\n" ([
      "<!-- GENERATED FILE — do not edit."
      "     source:     features/cli/zellij/etc/zellij/config.kdl"
      "     generator:  features/cli/zellij/keymap-card.nix"
      "     regenerate: nix eval --raw -f features/cli/zellij/keymap-card.nix"
      "-->"
      ""
      "# zellij keymap"
      ""
      "Generated from `features/cli/zellij/etc/zellij/config.kdl`. Editing this file changes"
      "nothing — edit the config and rebuild."
      ""
      "config.kdl sets `keybinds clear-defaults=true`, so what follows is the **whole** keymap."
      "zellij's documented defaults are not in effect, and zellij's own help screen reports those"
      "defaults rather than these keys. That is why this card exists."
      ""
      ("- mode blocks: " + toString (builtins.length modeBlocks))
      ("- `shared_except` blocks: " + toString (builtins.length sharedBlocks))
      ("- `bind` lines: " + toString (builtins.length parse.binds))
      ("- keys bound: " + toString keyCount)
      ""
      "Commented-out binds are not listed."
      ""
      "## Changing mode"
      ""
      "Every bind whose *only* action is a mode switch. A bind in a `shared_except` block applies"
      "in every mode except the ones it names. A mode can also be reached by a compound action"
      "(`pane`'s `c` is `SwitchToMode \"renamepane\"; PaneNameInput 0`), and those are in the"
      "per-block tables below rather than here."
      ""
      "| Keys | To mode | Declared in |"
      "| --- | --- | --- |"
    ]
    ++ switchRows
    ++ [
      ""
      "## Every binding, by block"
      ""
    ]
    ++ builtins.map blockCard parse.blocks)
