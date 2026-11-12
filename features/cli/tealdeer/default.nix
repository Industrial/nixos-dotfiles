# Tealdeer renders tldr pages: community cheatsheets for shell commands. Its binary is tldr.
#
# tldr is only worth having if the pages are already on disk, and the page cache is per-user
# mutable state that no derivation can own — `tldr --update` and `tldr --clear-cache` both
# rewrite it wholesale. Three things share the work:
#
#   1. A PINNED ARCHIVE seeds the cache during activation, once, only when it is absent. This
#      is what makes `tldr parted` answer on a freshly installed host, on the installer ISO,
#      and on anything that has never seen a network. tldr-pages v2.3 is the newest release
#      and is also what tealdeer's own default archive_source (`.../releases/latest/download`)
#      resolves to, and has resolved to since 2025-03-07 — so the seed is not a stale fork of
#      what `tldr --update` would fetch, it is the same bytes, pinned.
#   2. A USER TIMER refreshes it weekly from tealdeer's own archive_source, which makes the
#      pin a floor rather than a ceiling. Modelled on features/cli/atuin's
#      shell-history-checkpoint, including the deliberate absence of any
#      graphical-session.target ordering: huginn, mimir, muninn and the installer run a shell
#      and never start a graphical session.
#   3. config.toml turns auto_update OFF, so no interactive `tldr` ever blocks on a download.
#
# The alternatives, and why not:
#   - `tldr --update` on first use is the smallest thing that works, but the first `tldr` on a
#     new host needs the network and the user waits on 3.4 MB for a page they wanted in a
#     hurry.
#   - Fetching during activation makes `nixos-rebuild switch` network-dependent and able to
#     fail a switch over documentation.
#   - The timer on its own leaves nothing to answer until it has fired once, which on an
#     installer ISO is never — and the ISO is exactly where offline help earns its keep.
#
# What the seed costs, stated plainly: ~15 MB of pages in every host's system closure, and a
# `hash` beside a release tag that somebody has to bump when tldr-pages cuts v2.4. The timer
# is what keeps that bump from mattering day to day.
{
  pkgs,
  settings,
  ...
}: let
  # tldr-pages cuts a release roughly once a year. Bumping this means bumping `hash` too:
  # `nix store prefetch-file --json <url> | jq -r .hash`. The hash can also drift *without* a
  # tag bump: upstream rebuilds the release asset in place, so a fixed-output mismatch on an
  # unchanged `pagesRelease` is that, not a corrupted download — re-prefetch and repin.
  pagesRelease = "v2.3";

  pagesArchive = pkgs.fetchurl {
    url = "https://github.com/tldr-pages/tldr/releases/download/${pagesRelease}/tldr-pages.en.zip";
    hash = "sha256-2mWWVuxb3/VLYxlpLk+bY5EpQJDZgUkyhptMkse2Vlc=";
  };

  # tealdeer resolves a page at `<cache_dir>/tldr-pages/pages.<lang>/<platform>/<cmd>.md`:
  # TLDR_PAGES_DIR is the literal "tldr-pages" and `Language("en").directory_name()` is
  # "pages.en" (tealdeer-1.9.1 src/cache.rs). The release zip carries the platform directories
  # at its root, which is what `tldr --update` extracts into that same place — so this is the
  # layout tealdeer's own updater produces, not a guess at it.
  seedPages =
    pkgs.runCommand "tldr-pages-${pagesRelease}-en" {
      nativeBuildInputs = [pkgs.unzip];
    } ''
      mkdir -p $out/pages.en
      unzip -q ${pagesArchive} -d $out/pages.en
    '';

  cacheDir = "${settings.userdir}/.cache/tealdeer";
  pagesDir = "${cacheDir}/tldr-pages";
  configDir = "${settings.userdir}/.config/tealdeer";

  configFile = pkgs.writeTextFile {
    name = "tealdeer-config.toml";
    text = builtins.readFile ./config.toml;
  };

  refresh = pkgs.writeShellScript "tealdeer-pages-refresh" ''
    set -u
    # tealdeer downloads every archive before it deletes anything (src/cache.rs), so a refresh
    # that cannot reach the network leaves the pages already on disk exactly where they were.
    #
    # Which is why a failed refresh is not a failed unit: there is always a cache to fall back
    # on, activation put one there, and a host that was merely off the network would otherwise
    # show a red user unit after every boot. The signal that refreshing has genuinely stopped
    # working is tealdeer's own cache-age warning, which config.toml deliberately leaves on.
    if ! ${pkgs.tealdeer}/bin/tldr --update --quiet; then
      echo "tealdeer: page refresh failed; keeping the pages already in ${pagesDir}"
    fi
  '';
in {
  environment.systemPackages = with pkgs; [
    tealdeer
  ];

  # Named for this feature rather than the generic linkFile that
  # features/window-manager/alacritty already claims: two features writing one
  # activation-script name is an evaluation conflict, not a merge.
  system.activationScripts.linkTealdeerConfig = {
    text = ''
      mkdir -p ${configDir}
      # `tldr --seed-config` writes a config here, and so does a hand-edit. Keep either rather
      # than clobber it, the same way features/cli/atuin does.
      if [ -f ${configDir}/config.toml ] && [ ! -L ${configDir}/config.toml ]; then
        mv ${configDir}/config.toml ${configDir}/config.toml.backup
      fi
      ln -sfn ${configFile} ${configDir}/config.toml
      chown -R ${settings.username}:users ${configDir}
    '';
  };

  system.activationScripts.seedTealdeerPages = {
    text = ''
      # Only when absent. `tldr --update` and the refresh timer both replace this directory
      # wholesale, so re-seeding on every switch would quietly roll a current cache back to
      # the pinned release.
      if [ ! -e ${pagesDir} ]; then
        install -d -o ${settings.username} -g users -m 0755 ${cacheDir}
        echo "tealdeer: seeding the offline tldr page cache from tldr-pages ${pagesRelease}"
        # --no-preserve: the store copy is read-only and root-owned, and the user has to be
        # able to let `tldr --update` replace it later. Not preserving timestamps either is
        # what keeps `cache.age()` — the mtime of this directory — from reading as 1970 and
        # tripping the cache-age warning on a host that was seeded five minutes ago.
        cp -r --no-preserve=mode,ownership,timestamps ${seedPages} ${pagesDir}
        chown -R ${settings.username}:users ${pagesDir}
      fi
    '';
  };

  systemd.user.services.tealdeer-pages-refresh = {
    description = "Refresh the offline tldr page cache";

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${refresh}";
      # tealdeer resolves both its config and its cache against the XDG variables and a
      # systemd user manager sets neither XDG_CONFIG_HOME nor XDG_CACHE_HOME. Stated rather
      # than inherited, for the same reason features/cli/atuin states them.
      Environment = [
        "HOME=${settings.userdir}"
        "XDG_CONFIG_HOME=${settings.userdir}/.config"
        "XDG_CACHE_HOME=${settings.userdir}/.cache"
      ];
      # Documentation has no deadline; interactive use does.
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.tealdeer-pages-refresh = {
    description = "Weekly refresh of the offline tldr page cache";
    wantedBy = ["timers.target"];

    timerConfig = {
      OnCalendar = "weekly";
      # A host that is off on the trigger day still gets its refresh — and a host that has
      # never run it refreshes shortly after first boot instead of a week later.
      Persistent = true;
      # tldr-pages is one GitHub release asset. A whole fleet asking for it in the same second
      # is rude and buys nothing.
      RandomizedDelaySec = "6h";
    };
  };
}
