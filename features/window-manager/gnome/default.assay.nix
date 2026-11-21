# Assay: the GNOME desktop feature (with its dconf database and workspace launcher).
#
# Claims read the evaluated config. The cross-file claim worth having is that every
# extension the dconf database enables is actually installed by this feature: an enabled
# UUID with no package behind it is an extension GNOME silently never loads.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  user = nixos.defaultSettings.username;
  # GNOME's own module contributes databases too; ours is the locked one carrying the shell keys.
  ours =
    builtins.filter (d: (d.lockAll or false) && (d.settings or {}) ? "org/gnome/shell")
    cfg.programs.dconf.profiles.user.databases;
  shell = (builtins.head ours).settings."org/gnome/shell";
  installedUuids = map (p: p.extensionUuid) (builtins.filter (p: p ? extensionUuid) cfg.environment.systemPackages);
  df = cfg.fonts.fontconfig.defaultFonts;
in
  assay.suite "gnome" {
    # The two imports land: the dconf database and the workspace launcher unit.
    importsDconf = assay.eq (builtins.length ours) 1;
    importsWorkspaceSetup = assay.eq (cfg.systemd.user.services ? gnome-workspace-launcher) true;

    gnomeDesktop = assay.eq cfg.services.desktopManager.gnome.enable true;
    gdmLogin = assay.eq cfg.services.displayManager.gdm.enable true;
    keyringAndSettingsDaemon =
      assay.eq [cfg.services.gnome.gnome-keyring.enable cfg.services.gnome.gnome-settings-daemon.enable] [true true];
    coreShellOsServicesAndApps =
      assay.eq (with cfg.services.gnome; [core-shell.enable core-os-services.enable core-apps.enable]) [true true true];

    installsCoreApps =
      assay.eq (map (nixos.hasPackage cfg) ["nautilus" "gnome-tweaks" "dconf-editor" "gnome-console" "wmctrl"]) [true true true true true];
    everyEnabledExtensionIsInstalled =
      assay.eq (lib.subtractLists installedUuids shell.enabled-extensions) [];

    # Inter for UI text is gnome's; the monospace alias has exactly one writer, stylix, so
    # this feature leaves it at what an empty system has.
    uiFontsAreInter = assay.eq [df.serif df.sansSerif] [["Inter"] ["Inter"]];
    emojiFontIsNoto = assay.eq df.emoji ["Noto Color Emoji"];
    doesNotWriteMonospaceAlias = assay.eq df.monospace nixos.baseline.fonts.fontconfig.defaultFonts.monospace;
    installsUiFonts = assay.eq (map (p: builtins.elem p (map lib.getName cfg.fonts.packages)) ["inter" "jetbrains-mono"]) [true true];

    portalWithGtk =
      assay.eq [cfg.xdg.portal.enable (builtins.elem "xdg-desktop-portal-gtk" (map lib.getName cfg.xdg.portal.extraPortals))] [true true];
    waylandForElectron = assay.eq cfg.environment.variables.NIXOS_OZONE_WL "1";
    noCrashReporter =
      assay.eq (with cfg.environment.variables; [GNOME_DISABLE_CRASH_DIALOG GNOME_DISABLE_CRASH_REPORTER]) ["1" "1"];

    # Mutter reads ~/.config/monitors.xml; it is linked from the repo's copy.
    linksMonitorsXml = assay.eq (builtins.match ".*ln -sfn /nix/store/[^ ]+-monitors[.]xml /home/${user}/[.]config/monitors[.]xml.*"
      cfg.system.activationScripts.gnome-monitors.text
      != null)
    true;

    # vfiles (GH-188): monitors.xml, linked from the committed file.
    vfilesLinksMonitorsXml = let
      f = cfg.vfiles.files."${nixos.defaultSettings.userdir}/.config/monitors.xml";
    in
      assay.eq [f.mode (f.source == ./monitors.xml)] ["link" true];
  }
