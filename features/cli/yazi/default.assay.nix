# Colocated suite: systemPackages from stubbed pkgs, plus the two declared
# config files.
let
  assay = import ./../../../common/assay/default.nix;
  # `writeTextFile = args: args.name` keeps the activation `.text` forceable
  # without a real nixpkgs. `yazi.override` records its argument so the suite
  # can assert which preview companions get wrapped in; the stub must cover
  # every pkgs attribute default.nix touches, which is just these three.
  pkgs = {
    exiftool = "exiftool";
    writeTextFile = args: args.name;
    yazi.override = args: {
      drv = "yazi";
      inherit (args) extraPackages;
    };
  };
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "alice";
      userdir = "/home/alice";
    };
    inherit pkgs;
  };
  activation = mod.system.activationScripts.linkYaziConfig.text;
  # fromTOML doubles as the parse check: a malformed config fails the suite at
  # eval rather than silently at the next `yazi` launch.
  cfg = builtins.fromTOML (builtins.readFile ./yazi.toml);
  keymap = builtins.fromTOML (builtins.readFile ./keymap.toml);
  chords = keymap.mgr.prepend_keymap;
in
  assay.suite "yazi" {
    # One entry: the nixpkgs wrapper already prefixes yazi's PATH with jq,
    # poppler-utils, _7zz, ffmpeg-headless, fd, ripgrep, fzf, zoxide,
    # imagemagick, chafa, resvg and file, so only exiftool is added.
    systemPackages = assay.eq mod.environment.systemPackages [
      {
        drv = "yazi";
        extraPackages = ["exiftool"];
      }
    ];

    activationScriptDeclared =
      assay.eq (mod.system.activationScripts ? linkYaziConfig) true;
    # `linkFile` belongs to alacritty; a second definition collides on eval.
    doesNotClaimGenericLinkFile =
      assay.eq (mod.system.activationScripts ? linkFile) false;
    createsConfigDir =
      assay.eq
      (builtins.match ".*mkdir -p /home/alice/[.]config/yazi.*" activation != null)
      true;
    linksYaziToml =
      assay.eq
      (builtins.match
        ".*ln -sf yazi[.]toml /home/alice/[.]config/yazi/yazi[.]toml.*"
        activation
        != null)
      true;
    linksKeymapToml =
      assay.eq
      (builtins.match
        ".*ln -sf keymap[.]toml /home/alice/[.]config/yazi/keymap[.]toml.*"
        activation
        != null)
      true;

    configParses = assay.eq (builtins.isAttrs cfg) true;
    keymapParses = assay.eq (builtins.isAttrs keymap) true;

    previewIsTheWidestColumn = assay.eq cfg.mgr.ratio [1 3 4];
    sortsNaturally = assay.eq cfg.mgr.sort_by "natural";
    showsHiddenFiles = assay.eq cfg.mgr.show_hidden true;
    sizeInTheGutter = assay.eq cfg.mgr.linemode "size";
    previewWraps = assay.eq cfg.preview.wrap "yes";
    # Above the preset's 600x900; `[tasks] image_alloc` is still the ceiling.
    raisesImageBounds =
      assay.eq [cfg.preview.max_width cfg.preview.max_height] [1600 1200];

    # The preset already routes image/video/pdf/archive previews through
    # bundled plugins whose spawned binaries the wrapper supplies. Restating
    # the table here would be a second place for an upstream rename to rot,
    # and a stale previewer name shows up as "no preview", not as an error.
    doesNotRestatePreviewers = assay.eq (cfg ? plugin) false;
    # Likewise for openers: `[opener] reveal` is where the exiftool entry that
    # justifies the one added package lives.
    doesNotRestateOpeners =
      assay.eq (cfg ? opener || cfg ? open) false;

    # Prepend, not replace: the preset's manager bindings must all survive.
    keymapPrepends = assay.eq (keymap.mgr ? prepend_keymap) true;
    keymapDoesNotReplacePreset = assay.eq (keymap.mgr ? keymap) false;
    # A `plugin <name>` for an unbundled plugin does nothing when pressed.
    keymapUsesBuiltinCommandsOnly =
      assay.eq
      (builtins.all (c: builtins.match "plugin .*" c.run == null) chords)
      true;
    # `g h` (home) and `g d` (~/Downloads) stay the preset's.
    keymapKeepsPresetGotos =
      assay.eq
      (builtins.all (c: c.on != ["g" "h"] && c.on != ["g" "d"]) chords)
      true;
    # `~` is expanded by yazi, so no host path is baked into a config file.
    keymapHasNoHardcodedHome =
      assay.eq
      (builtins.all (c: builtins.match ".*/home/.*" c.run == null) chords)
      true;
  }
