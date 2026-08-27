# Alternatives to the *arr ecosystem — flat-file-config candidates
Researched 2026-08-24 (GitHub stars/activity checked live, nixpkgs packaging verified).
User requirement: config must be 100% syncable files (UI edits must never strand
state in sqlite) — roles needed: torrent downloader + indexer + download manager.

## Ratings (A=file-config purity, B=role coverage, C=health, D=NixOS fit)

1. Jackett + Transmission (+ Medusa) — A5 B4 C4 D4
   - Jackett: ServerConfig.json + ONE JSON PER INDEXER on disk → solves the
     "indexers locked in prowlarr.db" pain directly. 15.9k★, active daily.
   - Transmission: whole daemon state in settings.json; native services.transmission.
   - Medusa: config.ini, TV automation, ~2k★ active — TV-only (resprawl risk).
2. qBittorrent (keep) + Jackett or NZBHydra2 — A5 B3 C5 D4
   - NZBHydra2: single nzbhydra.yml meta-search over torrent+usenet indexers,
     1.7k★ active — arguably the better Prowlarr drop-in vs Jackett.
   - Gap: no download-manager role (usenet needs paid providers anyway).
3. Deluge + Jackett + cross-seed — A4 B3 C3 D3
   - Deluge core.conf file-backed; cross-seed (1.5k★, config.js) automates
     cross-seeding — complementary, not a manager.
4. rTorrent + ruTorrent — A5 B2 C3 D2
   - Most purely file-declarative client (.rtorrent.rc never UI-rewritten),
     but dated UX and DIY packaging; no indexer/manager story.
5. Riven (rivenmedia/riven, 817★) — A2 B5 C2 D1
   - Only true all-in-one outside arr (watchlist→search→download→library),
     but Postgres+Redis required and settings via .env — fails the file rule.
6. plex_debrid — A2 B3 C1 D1 — debrid-service-centric, stale since 2024-07.

## Excluded (and why)
- Flemmarr (345★): would have automated arr configs, DEAD since 2024-01;
  also just API automation, not file truth.
- autobrr (3k★ active): filters/rules live in sqlite — violates requirement.
- qui (4.4k★ active): qBit fleet manager, DB-backed settings — same violation.

## Single-manager answer for all content types
FlexGet (1,963★, pushed daily): ONE config.yml defines sources (Torznab/RSS/
scrapes), accept/reject+quality rules, schedules, targets. Daemon never rewrites
the config; WebUI is dashboard-only. TV/movies first-class; music/books/software
are recipe-level (write YAML once per source). NixOS ships BOTH the package and
a native `services.flexget` module pointing at a config file — full repo-owned
stack: Jackett JSONs + Transmission settings.json + FlexGet config.yml symlinked.
Pragmatic hybrid if YAML authoring feels heavy: keep Radarr/Lidarr, FlexGet for
TV + long tail.
