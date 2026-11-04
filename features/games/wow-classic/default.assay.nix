# Colocated suite: WoW Classic configuration
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    writeShellScriptBin = name: text: {inherit name text;};
  };
  settings = {
    hostname = "h";
    username = "alice";
  };
  mod = import ./default.nix {inherit pkgs settings;};

  scriptNamed = name:
    builtins.head (builtins.filter (p: p.name == name) mod.environment.systemPackages);

  linkScript = scriptNamed "link-wow-classic";
  seedScript = scriptNamed "seed-wow-character";

  # The script text is embedded into the module via builtins.readFile, so the
  # suite can assert on its content directly. `.` matches newlines in Nix
  # regexes, so a `.*needle.*` match works across the whole script.
  containsIn = script: needle: builtins.match ".*${needle}.*" script.text != null;
  contains = containsIn linkScript;
  seedContains = containsIn seedScript;
in
  assay.suite "wow-classic" {
    has-link-script = assay.eq (builtins.hasAttr "environment" mod && builtins.hasAttr "systemPackages" mod.environment) true;
    packages-non-empty = assay.eq (builtins.length mod.environment.systemPackages > 0) true;
    script-named-link-wow-classic = assay.eq linkScript.name "link-wow-classic";

    # Regression: the flavor directory is renamed by Blizzard per product
    # (_classic_era_ -> _classic_beta_ -> _forever_). Hardcoding one silently
    # stops linking after a product migration, so detect it instead.
    no-hardcoded-flavor-dir = assay.eq (contains "_classic_era_") false;
    detects-flavor-marker = assay.eq (contains "\\.flavor\\.info") true;
    honours-flavor-override = assay.eq (contains "WOW_FLAVOR_DIR") true;
    honours-root-override = assay.eq (contains "WOW_ROOT") true;

    # Both config trees are tracked in the repo and both get linked.
    links-wtf = assay.eq (contains "wtfTargetPath") true;
    links-interface = assay.eq (contains "interfaceTargetPath") true;

    # Regression: the previous version rm -rf'd live game settings and exited 0
    # when the install was missing, which created dangling symlinks.
    no-destructive-delete = assay.eq (contains "rm -rf") false;
    archives-existing-dirs = assay.eq (contains "pre-link-") true;
    refuses-dangling-symlinks = assay.eq (contains "Refusing to create a dangling symlink") true;

    # seed-wow-character gives a character an existing character's settings.
    has-seed-script = assay.eq (builtins.length mod.environment.systemPackages) 2;

    # The account slot and realm directory are both client-assigned, so the
    # seeder must cover every slot rather than assume one.
    seeds-every-account-slot = assay.eq (seedContains "slotPaths") true;

    # Addons keyed by AceDB need a profileKeys entry or the new character
    # silently gets a fresh default profile.
    maps-acedb-profiles = assay.eq (seedContains "profileKeys") true;

    # WoW writes these files CRLF; a seeded line must match or the file is
    # mixed-ending. The quoted-value guard stops a block-tracking slip from
    # splicing into the adjacent profiles table.
    preserves-crlf = assay.eq (seedContains "eol") true;

    # A space in a two-part character name becomes a hyphen in the directory.
    maps-space-to-hyphen = assay.eq (seedContains "dirNameFor") true;

    # Re-running after a first login must be safe.
    does-not-clobber-by-default = assay.eq (seedContains "already present") true;
  }
