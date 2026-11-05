# Colocated suite: btop's package, generated theme and generated config.
#
# btop is silent about a theme key it does not recognise and about a theme file it cannot
# find -- a mistake in either shows up as "btop looks slightly wrong", never as an error. So
# the generated theme's key names are checked against the vocabulary btop itself ships, read
# out of the real package. That is import-from-derivation, which is allowed here because this
# is a test; features/window-manager/stylix/palette.nix keeps it out of the host eval path.
let
  assay = import ./../../../common/assay/default.nix;
  realPkgs = import <nixpkgs> {};
  palette = import ./../../window-manager/stylix/palette.nix;

  # `writeTextFile = args: args.text` makes the generated files readable here as strings.
  pkgs = {
    btop = "btop";
    writeTextFile = args: args.text;
  };
  mod = import ./default.nix {
    inherit pkgs;
    settings = {
      hostname = "h";
      username = "alice";
      userdir = "/home/alice";
    };
  };

  theme = mod.environment.etc."btop/themes/stylix.theme".source;
  conf = mod.environment.etc."btop/btop.conf".source;
  activation = mod.system.activationScripts.linkBtopConfig.text;

  lines = s: builtins.filter builtins.isString (builtins.split "\n" s);
  # `theme[key]="#rrggbb"` -- the only shape btop's own theme files use.
  themeEntries =
    builtins.filter (m: m != null)
    (map (l: builtins.match "theme[[]([a-z_]+)[]]=\"(#[0-9a-f]{6})\"" l) (lines theme));
  themeKeys = map (m: builtins.elemAt m 0) themeEntries;
  themeColors = map (m: builtins.elemAt m 1) themeEntries;

  # btop's own bundled themes, used as the authoritative key vocabulary for this version.
  shippedThemes = "${realPkgs.btop}/share/btop/themes";
  shippedKeys = builtins.foldl' (acc: f:
    acc
    ++ (map (m: builtins.elemAt m 0)
      (builtins.filter (m: m != null)
        (map (l: builtins.match "theme[[]([a-z_]+)[]]=.*" l)
          (lines (builtins.readFile "${shippedThemes}/${f}")))))) []
  (builtins.attrNames (builtins.readDir shippedThemes));

  confLines =
    builtins.filter (m: m != null)
    (map (l: builtins.match "([a-z_]+) = (.*)" l) (lines conf));
  confOf = key:
    builtins.head
    (map (m: builtins.elemAt m 1)
      (builtins.filter (m: builtins.elemAt m 0 == key) confLines));

  paletteValues = builtins.attrValues palette.withHash;
in
  assay.suite "btop" {
    systemPackages = assay.eq mod.environment.systemPackages ["btop"];

    # Not vacuous: a theme that silently stopped being generated would read as zero entries
    # and every `builtins.all` below would pass on the empty list.
    themeIsNotEmpty = assay.eq (builtins.length themeEntries >= 38) true;
    everyThemeKeyIsKnownToBtop =
      assay.eq (builtins.all (k: builtins.elem k shippedKeys) themeKeys) true;
    # If the package ever stops shipping themes, the check above would pass on an empty
    # vocabulary. This is what notices.
    btopShipsThemesToCompareAgainst =
      assay.eq (builtins.length shippedKeys > 30) true;
    everyThemeColorIsFromThePalette =
      assay.eq (builtins.all (v: builtins.elem v paletteValues) themeColors) true;
    backgroundIsBase00 =
      assay.eq (builtins.elem "theme[main_bg]=\"${palette.withHash.base00}\"" (lines theme))
      true;

    # The config is the only thing that selects the theme; if this stops naming the file that
    # the same module installs, btop falls back to its own default and says nothing.
    confNamesTheGeneratedTheme =
      assay.eq (confOf "color_theme") "\"/etc/btop/themes/stylix.theme\"";
    installsThatExactPath =
      assay.eq (mod.environment.etc ? "btop/themes/stylix.theme") true;
    # btop would otherwise paint base00 over a terminal already painting base00, which on a
    # transparent window is a visible rectangle.
    leavesBackgroundToTheTerminal =
      assay.eq (confOf "theme_background") "False";
    truecolorEnabled = assay.eq (confOf "truecolor") "True";

    # `linkFile` belongs to alacritty; a second definition collides on eval.
    doesNotClaimGenericLinkFile =
      assay.eq (mod.system.activationScripts ? linkFile) false;
    # A writable copy rather than a store symlink, because btop rewrites its whole config on
    # exit and a read-only path would make every quit an error. `install`, not `ln -sf`.
    installsConfigAsWritableCopy =
      assay.eq
      (builtins.match ".*install -m 0644 /etc/btop/btop[.]conf /home/alice/[.]config/btop/btop[.]conf.*"
        activation
        != null)
      true;
    doesNotSymlinkTheConfig =
      assay.eq (builtins.match ".*ln -sf.*btop[.]conf.*" activation != null) false;
    # Activation runs as root, so the copy would otherwise be root-owned and btop still could
    # not write it -- which would defeat the whole reason for copying.
    handsTheCopyToTheUser =
      assay.eq
      (builtins.match ".*chown alice /home/alice/[.]config/btop/btop[.]conf.*"
        activation
        != null)
      true;
  }
