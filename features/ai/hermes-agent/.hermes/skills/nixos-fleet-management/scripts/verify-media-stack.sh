#!/usr/bin/env bash
# hermes-verify: ad-hoc verification of the mimir media stack
# (features/media/invidious/default.nix + hosts/mimir/configuration.nix).
#
# Checks the MERGED evaluated config (eval-level) AND the live host (runtime):
#   eval:    postgresql port=5434, invidious trust hba rules present,
#            all 9 media units exist, homarr absent
#   runtime: postgresql + 9 media units active, HTTP probe per service port,
#            container stack still owning 5432 (collision fix holds)
# Exit 0 = all clean; 1 = any violation.
set -u
cd /home/tom/.dotfiles || exit 1
fail=0

echo "== eval: mimir merged config =="
json="$(nix eval --json .#nixosConfigurations.mimir --apply 'cfg: let u = cfg.config.systemd.units; names = ["jellyfin" "lidarr" "sonarr" "radarr" "prowlarr" "readarr" "seerr" "invidious" "qbittorrent-nox"]; in { pg = cfg.config.services.postgresql.settings.port or null; hba = cfg.config.services.postgresql.authentication; present = builtins.listToAttrs (map (n: { name = n; value = builtins.hasAttr (n + ".service") u; }) names); homarr = builtins.hasAttr "homarr.service" u; }' 2>/dev/null | tail -1)"
if [[ -z "$json" ]]; then echo "  EVAL FAILED (no json)"; fail=1; else
  pg="$(jq -r '.pg' <<<"$json")"
  hba_trust="$(jq -r '.hba' <<<"$json" | grep -c 'host invidious invidious 127.0.0.1/32 trust')"
  missing="$(jq -r '.present | to_entries[] | select(.value == false) | .key' <<<"$json")"
  homarr="$(jq -r '.homarr' <<<"$json")"
  echo "  pg_port=$pg invidious_hba_trust=$hba_trust homarr_present=$homarr missing_units=${missing:-none}"
  [[ "$pg" == "5434" && "$hba_trust" -ge 1 && "$homarr" == "false" && -z "$missing" ]] || fail=1
fi

echo "== runtime: mimir live checks =="
remote_out="$(printf '%s\n' \
  'for s in postgresql jellyfin lidarr sonarr radarr prowlarr qbittorrent-nox readarr seerr invidious; do printf "%s=%s\n" $s $(systemctl is-active $s); done' \
  'for p in 8096 8686 8989 7878 9696 8080 8787 5055 4000; do printf "port_%s=%s\n" $p $(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:$p/); done' \
  'sudo ss -tln | grep -q ":5432 " && echo containers_own_5432=yes || echo containers_own_5432=no' \
| ssh -o BatchMode=yes mimir -- bash -s 2>&1)"

down="$(grep '=inactive\|=failed\|=activating' <<<"$remote_out")"
bad_ports="$(grep -E '^port_[0-9]+=' <<<"$remote_out" | grep -vE '=(2|3)[0-9][0-9]$')"
containers_5432="$(grep '^containers_own_5432=' <<<"$remote_out" | cut -d= -f2)"

echo "$remote_out" | sed 's/^/  /'
[[ -z "$down" ]] || { echo "  DOWN UNITS: $down"; fail=1; }
[[ -z "$bad_ports" ]] || { echo "  BAD PORTS: $bad_ports"; fail=1; }
[[ "$containers_5432" == "yes" ]] || { echo "  5432 no longer held by containers?!"; fail=1; }

echo "RESULT: $([[ $fail -eq 0 ]] && echo PASS || echo FAIL)"
exit $fail
