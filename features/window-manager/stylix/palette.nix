# Pure projection of the base16 scheme this fleet runs on.
#
# The scheme's source of truth is upstream YAML: `gruvbox-dark-hard.yaml` out of the
# commit-pinned tinted-theming/schemes checkout in ./derivations/tinted-theming-schemes.nix.
# That YAML lives in a derivation output, so reading it during module evaluation would mean
# import-from-derivation on every host eval — and this repo has already decided against that
# (see features/security/stig/lib/parse-xccdf.nix: "the NixOS module eval path must stay free
# of import-from-derivation"). So the sixteen colours are projected here, by hand, once.
#
# Drift is caught rather than trusted: ./palette.assay.nix reads the real YAML out of the
# pinned derivation — IFD is fine in a *test*, which is not the module eval path — parses it,
# and fails if any of the sixteen values, the scheme name, the variant, or the pin itself
# disagrees with this file. Bumping the `rev` in derivations/tinted-theming-schemes.nix
# without re-projecting here is a red suite, not a silent repaint.
#
# Depends on builtins only — no lib, no pkgs — so every consumer can import it with no
# fixture, including the `features/cli/*` modules that must keep working on a host which
# never imports profiles/desktop.nix (and therefore has no stylix module at all).
let
  # Must match `rev` in ./derivations/tinted-theming-schemes.nix. Asserted by the suite.
  sourceRev = "395074124283df993571f2abb9c713f413b76e6e";

  slug = "gruvbox-dark-hard";

  # Bare six-digit hex, exactly as the YAML carries it.
  colors = {
    base00 = "1d2021"; # default background
    base01 = "3c3836"; # lighter background (status bars, line numbers)
    base02 = "504945"; # selection background
    base03 = "665c54"; # comments, invisibles, line highlight
    base04 = "bdae93"; # dark foreground (status bar text)
    base05 = "d5c4a1"; # default foreground
    base06 = "ebdbb2"; # light foreground
    base07 = "fbf1c7"; # lightest background
    base08 = "fb4934"; # red — variables, diff deleted
    base09 = "fe8019"; # orange — integers, constants
    base0A = "fabd2f"; # yellow — classes, search background
    base0B = "b8bb26"; # green — strings, diff inserted
    base0C = "8ec07c"; # aqua — support, regex, escapes
    base0D = "83a598"; # blue — functions, headings
    base0E = "d3869b"; # purple — keywords, diff changed
    base0F = "d65d0e"; # brown — deprecated, embedded tags
  };

  withHash = builtins.mapAttrs (_: v: "#${v}") colors;

  # The base16 terminal mapping, as specified by tinted-theming/tinted-shell and as stylix's
  # own terminal targets emit it. Positions 0-15 are the ANSI slots every terminal app
  # inherits; 16-21 carry the six base16 colours ANSI has no slot for.
  #
  # Slots 9-14 deliberately repeat 1-6: base16 spends its "bright" range on accents rather
  # than on lighter variants, so bold red is the same red. That is the specification, not an
  # omission, and matching it is what lets a `bold red` in starship.toml or bat's `base16`
  # theme land on this scheme instead of on a terminal default.
  ansiNames = [
    "base00" # 0  black
    "base08" # 1  red
    "base0B" # 2  green
    "base0A" # 3  yellow
    "base0D" # 4  blue
    "base0E" # 5  magenta
    "base0C" # 6  cyan
    "base05" # 7  white
    "base03" # 8  bright black
    "base08" # 9  bright red
    "base0B" # 10 bright green
    "base0A" # 11 bright yellow
    "base0D" # 12 bright blue
    "base0E" # 13 bright magenta
    "base0C" # 14 bright cyan
    "base07" # 15 bright white
    "base09" # 16 orange
    "base0F" # 17 brown
    "base01" # 18
    "base02" # 19
    "base04" # 20
    "base06" # 21
  ];
in {
  inherit colors withHash ansiNames;

  scheme = {
    inherit slug sourceRev;
    name = "Gruvbox dark, hard";
    system = "base16";
    variant = "dark";
  };

  # "#rrggbb" per terminal colour slot, indexed by position in the list above.
  ansi = map (n: withHash.${n}) ansiNames;
}
