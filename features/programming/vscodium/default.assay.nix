# Assay: VSCodium, kept in step with features/programming/cursor.
#
# VSCodium mirrors the cursor feature. These claims catch the two extension lists drifting
# apart, and the settings link pointing anywhere but Cursor's files. Both lists are read from
# the evaluated packages: an overlay wraps vscode-with-extensions.override and keeps the
# list each feature called it with, so what is compared is what each editor is built with.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  recordExtensions = {
    nixpkgs.overlays = [
      (final: prev: {
        vscode-with-extensions =
          prev.vscode-with-extensions
          // {
            override = args:
              (prev.vscode-with-extensions.override args)
              // {
                recordedEditor = args.vscode;
                recordedExtensions = args.vscodeExtensions;
              };
          };
      })
    ];
  };
  wrapped = name: module: let
    cfg = nixos.eval {modules = [module recordExtensions];};
  in
    lib.findFirst (p: lib.getName p == name) null cfg.environment.systemPackages;
  cfg = nixos.eval {modules = [./default.nix recordExtensions];};
  codium = wrapped "vscodium" ./default.nix;
  cursor = wrapped "cursor" ../cursor/default.nix;
  ids = drv: map (e: e.vscodeExtUniqueId) drv.recordedExtensions;
  codiumIds = ids codium;
  cursorIds = ids cursor;
  home = nixos.defaultSettings.userdir;
  activation = cfg.system.activationScripts.linkVscodiumConfig.text;
  activationHas = needle: lib.hasInfix needle activation;
in
  assay.suite "vscodium" {
    # The one sanctioned difference: Microsoft's Remote-SSH only runs on Microsoft builds, so
    # VSCodium carries the open-source jeanp413.open-remote-ssh in its place.
    sameExtensionsAsCursor =
      assay.eq (lib.remove "jeanp413.open-remote-ssh" codiumIds) (lib.remove "ms-vscode-remote.remote-ssh" cursorIds);
    usesOpenRemoteSsh = assay.eq (builtins.elem "jeanp413.open-remote-ssh" codiumIds) true;
    noMicrosoftRemoteSsh = assay.eq (builtins.elem "ms-vscode-remote.remote-ssh" codiumIds) false;

    usesVscodium = assay.eq codium.recordedEditor.pname "vscodium";
    installsSameLanguageTooling = assay.eq (map (nixos.hasPackage cfg) ["alejandra" "nixd" "ty" "uv"]) [true true true true];

    # settings.json and keybindings.json are symlinks to Cursor's files in the repo, so an
    # edit in either editor shows up in both; a real file found there is moved aside.
    linksCursorSettings =
      assay.eq (activationHas ''ln -sfn "${home}/.dotfiles/features/programming/cursor/.config/Cursor/User/$file" "$target"'') true;
    linksSettingsAndKeybindings = assay.eq (activationHas "for file in settings.json keybindings.json; do") true;
    backsUpRealFiles = assay.eq (activationHas ''mv "$target" "$target.backup"'') true;
    linksIntoVscodiumUserDir = assay.eq (activationHas ''target="${home}/.config/VSCodium/User/$file"'') true;

    # vfiles (GH-188): both files linked from Cursor's checkout dir, the committed copies as
    # fallbacks.
    vfilesLinksCursorsFiles = assay.eq (builtins.mapAttrs (_: f: [f.source (builtins.pathExists f.fallback)]) cfg.vfiles.files) {
      "${home}/.config/VSCodium/User/settings.json" = ["${home}/.dotfiles/features/programming/cursor/.config/Cursor/User/settings.json" true];
      "${home}/.config/VSCodium/User/keybindings.json" = ["${home}/.dotfiles/features/programming/cursor/.config/Cursor/User/keybindings.json" true];
    };
  }
