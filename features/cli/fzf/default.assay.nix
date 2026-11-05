# Colocated suite: systemPackages and fzf session variables from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {fzf = "fzf";};
  mod = import ./default.nix {inherit pkgs;};
  env = mod.environment.sessionVariables;
  has = pattern: builtins.match ".*${pattern}.*" env.FZF_DEFAULT_OPTS != null;

  palette = import ./../../window-manager/stylix/palette.nix;
  paletteValues = builtins.attrValues palette.withHash;

  # FZF_DEFAULT_OPTS is one flat string, so the colour flags have to be picked back out of
  # it. Split on whitespace and commas, keep the `element:value` pairs that follow a
  # `--color=`, and the result is the colour spec fzf itself will parse -- including any
  # stray one somebody appends later, which is the point.
  optWords =
    builtins.filter builtins.isString
    (builtins.split "[ ,]" env.FZF_DEFAULT_OPTS);
  colorPairs =
    builtins.filter (m: m != null)
    (map (w: builtins.match "(--color=)?([a-z+]+):(#?[0-9a-zA-Z]+)" w) optWords);
  # `--color=always` belongs to the bat/eza preview commands, not to fzf's own palette, so
  # pairs are what is kept: a bare `always` has no `element:value` shape and drops out here.
  colorOf = element:
    builtins.head
    (map (m: builtins.elemAt m 2)
      (builtins.filter (m: builtins.elemAt m 1 == element) colorPairs));
  emittedColors = map (m: builtins.elemAt m 2) colorPairs;
in
  assay.suite "fzf" {
    systemPackages = assay.eq mod.environment.systemPackages ["fzf"];
    defaultCommand = assay.eq env.FZF_DEFAULT_COMMAND "fd --type f --hidden --exclude .git";
    layout = assay.eq (has "--layout=reverse") true;
    previewFiles = assay.eq (has "bat --style=numbers") true;
    previewDirectories = assay.eq (has "eza --tree") true;
    # Wave 7 replaced the "stay neutral" tripwire that used to live here. fzf now carries
    # explicit hex, so what is worth guarding is no longer its absence but its *provenance*:
    # every colour must be a value from the shared palette and nothing else, so a
    # hand-picked colour fails even though a hand-picked colour is now syntactically allowed.
    colorsAreFromThePalette =
      assay.eq (builtins.all (v: builtins.elem v paletteValues) emittedColors) true;
    # Guard the handful whose exact identity matters, rather than only the set membership:
    # `gutter` must equal the terminal background or unselected rows sit in a visible box,
    # and `bg`/`bg+` must differ or the current row stops being distinguishable.
    gutterMatchesBackground = assay.eq (colorOf "gutter") palette.withHash.base00;
    backgroundIsBase00 = assay.eq (colorOf "bg") palette.withHash.base00;
    currentRowIsDistinct =
      assay.eq (colorOf "bg+" != colorOf "bg") true;
    # The sixteen base16 names cover everything here; a 256-colour index or an ANSI name
    # would be a second colour vocabulary in the same string.
    everyColorIsHex =
      assay.eq (builtins.all (v: builtins.match "#[0-9a-f]{6}" v != null) emittedColors) true;
  }
