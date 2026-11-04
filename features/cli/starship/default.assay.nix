# Colocated suite: systemPackages from stubbed pkgs, plus the declared prompt.
let
  assay = import ./../../../common/assay/default.nix;
  # `writeTextFile = args: args.name` keeps the activation `.text` forceable
  # without a real nixpkgs: the stub must cover every pkgs attribute the text
  # interpolates, which here is writeTextFile and nothing else.
  pkgs = {
    starship = "starship";
    writeTextFile = args: args.name;
  };
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "alice";
      userdir = "/home/alice";
    };
    inherit pkgs;
  };
  activation = mod.system.activationScripts.linkStarshipConfig.text;
  # fromTOML doubles as the parse check: a malformed starship.toml fails the
  # suite at eval rather than silently at the first prompt.
  cfg = builtins.fromTOML (builtins.readFile ./starship.toml);
  # The base16 scheme is owned outside this feature, so every style here must
  # stay a named ANSI colour -- no hex literals to unpick later.
  styles = [
    cfg.directory.style
    cfg.git_branch.style
    cfg.git_state.style
    cfg.git_status.style
    cfg.nix_shell.style
    cfg.direnv.style
    cfg.cmd_duration.style
    cfg.status.style
    cfg.time.style
    cfg.character.success_symbol
    cfg.character.error_symbol
    cfg.character.vimcmd_symbol
  ];
in
  assay.suite "starship" {
    systemPackages = assay.eq mod.environment.systemPackages ["starship"];

    activationScriptDeclared =
      assay.eq (mod.system.activationScripts ? linkStarshipConfig) true;
    # `linkFile` belongs to alacritty; a second definition collides on eval.
    doesNotClaimGenericLinkFile =
      assay.eq (mod.system.activationScripts ? linkFile) false;
    createsConfigDir =
      assay.eq
      (builtins.match ".*mkdir -p /home/alice/[.]config.*" activation != null)
      true;
    linksStarshipToml =
      assay.eq
      (builtins.match
        ".*ln -sf starship[.]toml /home/alice/[.]config/starship[.]toml.*"
        activation
        != null)
      true;

    configParses = assay.eq (builtins.isAttrs cfg) true;
    formatIsExplicit =
      assay.eq cfg.format
      "$directory$git_branch$git_state$git_status$nix_shell$direnv$cmd_duration$status$line_break$character";
    clockLivesInRightFormat = assay.eq cfg.right_format "$time";
    clockEnabled = assay.eq cfg.time.disabled false;
    gitStatusShowsStash =
      assay.eq (builtins.match ".*[$]stashed.*" cfg.git_status.format != null) true;
    gitStatusStashSymbolEscaped = assay.eq cfg.git_status.stashed "\\$";
    direnvEnabled = assay.eq cfg.direnv.disabled false;
    nixShellHeuristicOff = assay.eq cfg.nix_shell.heuristic false;
    cmdDurationThreshold = assay.eq cfg.cmd_duration.min_time 500;
    exitStatusEnabled = assay.eq cfg.status.disabled false;
    viModeIndicator = assay.hasAttrs cfg.character [
      "vimcmd_symbol"
      "vimcmd_visual_symbol"
      "vimcmd_replace_symbol"
      "vimcmd_replace_one_symbol"
    ];
    paletteStaysNeutral =
      assay.eq (builtins.all (s: builtins.match ".*#.*" s == null) styles) true;
    noPaletteOverride = assay.eq (cfg ? palettes || cfg ? palette) false;
  }
