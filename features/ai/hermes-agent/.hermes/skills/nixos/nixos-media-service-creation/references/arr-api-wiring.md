# Prowlarr *arr application wiring — API quirks (verified live 2026-08-23)

Findings from wiring Sonarr/Radarr/Readarr/Lidarr into Prowlarr via its
REST API on the fleet's nixpkgs pin (Prowlarr 2.x). Verified by direct
curl experiments on mimir; encode these, don't re-derive them.

## enable derives from syncLevel, NOT from the enable field

- POSTing an application with `"enable": true` stores it with `enable: false`.
- PUTting `{enable: true}` (minimal or full-body echo) is accepted (202) but
  leaves `enable` false.
- The stored object carries `"syncLevel": "disabled"` when you omit it —
  that is what renders the app inactive.
- **Fix**: send `"syncLevel": "fullSync"` in the POST/PUT body. The app then
  shows `enable: true` and indexers actually sync.

## Commands

- `ApplicationsSync` does NOT exist on current builds: POST /command returns
  HTTP 500 "Sequence contains no matching element".
- `ApplicationTestAll` also 500s via /command.
- **`ApplicationIndexerSync` works** (HTTP 201) — use it to push indexer
  changes to applications after registration.

## PUT echo-back trap

GET /applications/{id} omits `implementation` / `configContract`. PUTting a
modified GET response fails validation:

```
-- Implementation: 'Implementation' must not be empty.
-- ConfigContract: 'Config Contract' must not be empty.
```

So idempotent updates must always send the FULL body built in code (name,
implementation, configContract, syncLevel, fields, tags, profileId, enable),
never a mutated GET result.

## Working request shape

POST /api/v1/applications (X-Api-Key header):

```json
{
  "name": "Sonarr",
  "implementation": "Sonarr",
  "configContract": "SonarrSettings",
  "syncLevel": "fullSync",
  "tags": [],
  "profileId": 1,
  "enable": true,
  "fields": [
    {"name": "baseUrl", "value": "http://127.0.0.1:8989"},
    {"name": "apiKey",  "value": "<sonarr api key>"},
    {"name": "syncCategories", "value": [5000]}
  ]
}
```

Implementation/configContract per app:
sonarr→Sonarr/SonarrSettings, radarr→Radarr/RadarrSettings,
readarr→Readarr/ReadarrSettings, lidarr→Lidarr/LidarrSettings.

Standard sync categories: sonarr 5000, radarr 2000, lidarr 3000,
readarr 7000 (tv/movies/audio/books).

Readiness probe before talking to the API: GET /system/status until 200
(app takes seconds to boot; poll up to ~120s).

## Key seeding into config.xml

*arr apps generate a random ApiKey at first run. To make keys declarative:
sed-replace `<ApiKey>...</ApiKey>` inside `/data/services/<app>/config.xml`
(only when different), then restart that app so the in-memory key doesn't
overwrite the file back. Files without `<ApiKey>` yet get one inserted
before `</Config>`. See `features/media/arr-wiring.nix` for the working
script.

## What stays manual (no API bootstrap)

- Adding actual indexers to Prowlarr (tracker accounts).
- Download client (qbittorrent) + root folder per app — one-time UI clicks.
- Homarr tiles/integrations — stored in homarr's own DB; but the keys are
  all in `features/media/api-keys.nix`, so pasting them is trivial.
