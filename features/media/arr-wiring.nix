# Automatic *arr inter-service wiring.
#
# Two idempotent oneshot services:
#   arr-api-key-seed — enforces the declared API keys from ./api-keys.nix in
#     each app's config.xml (restarts only apps whose key had to change).
#   prowlarr-sync — registers Sonarr/Radarr/Readarr/Lidarr as Prowlarr
#     applications over the REST API and triggers indexer sync, so indexers
#     added in Prowlarr propagate automatically.
#
# Result: no manual copy-pasting of API keys between apps.
{
  pkgs,
  lib,
  ...
}: let
  apiKeys = import ./api-keys.nix;
  apps = {
    prowlarr.port = 9696;
    sonarr.port = 8989;
    radarr.port = 7878;
    readarr.port = 8787;
    lidarr.port = 8686;
    whisparr.port = 6969;
  };
  appList = builtins.attrNames apps;

  # "app key" lines consumed by the seed script.
  keyLines = lib.concatStringsSep "\n" (map (n: "${n} ${apiKeys.${n}}") appList);

  seedScript = pkgs.writeShellScript "arr-api-key-seed" ''
    set -eu
    todo=""
    while read -r app want; do
      case "''${app:-}" in "") continue ;; esac
      cfg="/data/services/$app/config.xml"
      [[ -f "$cfg" ]] || { echo "skip $app (not initialised yet)"; continue; }
      if grep -q '<ApiKey>' "$cfg"; then
        cur="$(sed -n 's@.*<ApiKey>\([^<]*\)</ApiKey>.*@\1@p' "$cfg")"
        [[ "$cur" == "$want" ]] && continue
        sed -i "s@<ApiKey>[^<]*</ApiKey>@<ApiKey>$want</ApiKey>@" "$cfg"
      else
        # First-run file without an ApiKey element: insert one.
        grep -q '</Config>' "$cfg" || { echo "skip $app (unrecognised xml)"; continue; }
        sed -i "s@</Config>@  <ApiKey>$want</ApiKey>\n</Config>@" "$cfg"
      fi
      echo "seeded api key: $app"
      todo="$todo $app"
    done <<EOF
${keyLines}
EOF
    if [[ -n "$todo" ]]; then
      # Stop -> seed happened above -> start, so apps never persist their
      # old in-memory key back over the file.
      for app in ${lib.concatStringsSep " " appList}; do
        [[ " $todo " == *" $app "* ]] && systemctl stop "$app.service" 2>/dev/null || true
      done
      sleep 2
      for app in ${lib.concatStringsSep " " appList}; do
        [[ " $todo " == *" $app "* ]] && systemctl start "$app.service" 2>/dev/null || true
      done
    else
      echo "all api keys already match"
    fi
  '';

  prowlarrSync = pkgs.writers.writePython3 "prowlarr-sync" {} ''
    import json
    import os
    import time
    import urllib.request

    base = "http://127.0.0.1:${toString apps.prowlarr.port}/api/v1"
    prowlarr_key = os.environ["PROWLARR_KEY"]
    targets = json.loads(os.environ["TARGETS"])
    categories = json.loads(os.environ["CATEGORIES"])


    def req(method, path, key, body=None):
        data = json.dumps(body).encode() if body is not None else None
        r = urllib.request.Request(base + path, data=data, method=method)
        r.add_header("Content-Type", "application/json")
        r.add_header("X-Api-Key", key)
        return urllib.request.urlopen(r, timeout=20)


    deadline = time.time() + 120
    while True:
        try:
            req("GET", "/system/status", prowlarr_key).read()
            break
        except Exception as e:
            if time.time() > deadline:
                raise SystemExit(f"prowlarr never became ready: {e}")
            time.sleep(3)

    profiles = json.loads(req("GET", "/appProfile", prowlarr_key).read())
    profile_id = profiles[0]["id"]
    existing_apps = json.loads(
        req("GET", "/applications", prowlarr_key).read())
    existing = {a["name"]: a for a in existing_apps}

    implementations = {
        "sonarr": ("Sonarr", "Sonarr", "SonarrSettings"),
        "radarr": ("Radarr", "Radarr", "RadarrSettings"),
        "readarr": ("Readarr", "Readarr", "ReadarrSettings"),
        "lidarr": ("Lidarr", "Lidarr", "LidarrSettings"),
        "whisparr": ("Whisparr", "Whisparr", "WhisparrSettings"),
    }

    for app, (name, implementation, contract) in implementations.items():
        target = targets[app]
        body = {
            "name": name,
            "implementation": implementation,
            "configContract": contract,
            # enable derives from syncLevel on current builds; "disabled"
            # (the default when omitted) renders the app inactive.
            "syncLevel": "fullSync",
            "fields": [
                {"name": "baseUrl", "value": target["url"]},
                {"name": "apiKey", "value": target["key"]},
                {"name": "syncCategories",
                 "value": categories[app]},
            ],
            "tags": [],
            "profileId": profile_id,
            "enable": True,
        }
        if name in existing:
            cur = {
                f.get("name"): f.get("value")
                for f in existing[name].get("fields", [])
            }
            same = (
                cur.get("baseUrl") == target["url"]
                and cur.get("apiKey") == target["key"]
                and existing[name].get("enable", False)
            )
            if same:
                print(f"{app}: unchanged")
                continue
            body["id"] = existing[name]["id"]
            req("PUT", f"/applications/{body['id']}",
                prowlarr_key, body).read()
            print(f"{app}: updated")
        else:
            req("POST", "/applications", prowlarr_key, body).read()
            print(f"{app}: registered")

    # Indexer sync to applications: the ApplicationsSync command is not
    # exposed by current Prowlarr builds, but ApplicationIndexerSync is.
    req("POST", "/command", prowlarr_key,
        {"name": "ApplicationIndexerSync"}).read()
    print("wiring complete")
  '';
in {
  systemd.services.arr-api-key-seed = {
    description = "Seed declared API keys into *arr config.xml files";
    after = ["network.target"] ++ map (a: "${a}.service") appList;
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = seedScript;
    };
  };

  systemd.services.prowlarr-sync = {
    description = "Register *arr apps in Prowlarr and trigger indexer sync";
    after = ["arr-api-key-seed.service" "prowlarr.service"]
      ++ map (a: "${a}.service") (builtins.attrNames (removeAttrs apps ["prowlarr"]));
    wants = ["prowlarr.service"];
    wantedBy = ["multi-user.target"];
    environment = {
      PROWLARR_KEY = apiKeys.prowlarr;
      TARGETS = builtins.toJSON (builtins.mapAttrs
        (n: _: {
          url = "http://127.0.0.1:${toString apps.${n}.port}";
          key = apiKeys.${n};
        })
        (removeAttrs apps ["prowlarr"]));
      CATEGORIES = builtins.toJSON {
        sonarr = [5000];
        radarr = [2000];
        lidarr = [3000];
        readarr = [7000];
        whisparr = [8000];
      };
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = prowlarrSync;
    };
  };
}
