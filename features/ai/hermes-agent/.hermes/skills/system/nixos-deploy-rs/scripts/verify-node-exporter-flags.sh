#!/usr/bin/env bash
# Verify that services.prometheus.exporters.node collector flags never repeat
# in each host's MERGED NixOS config (evaluated, not source files).
#
# Root cause this guards against: NixOS renders each enabledCollectors entry
# as `--collector.X` and each disabledCollectors entry as `--no-collector.X`;
# node_exporter (Go flag parser) rejects repeated flags, the unit crash-loops
# to start-limit-hit, and deploy-rs magic-rollbacks the deploy. List options
# CONCATENATE across module imports, so per-file-clean != merged-clean.
#
# Usage: verify-node-exporter-flags.sh [repo-root] [host ...]
#   repo-root defaults to cwd; hosts default to all nixosConfigurations.
# bash+jq only (works on hosts without python).
set -euo pipefail
cd "${1:-.}"
shift || true

UNIT="prometheus-node-exporter.service"
APPLY='cfg: let e = cfg.config.services.prometheus.exporters.node; in { enabled = e.enabledCollectors or []; disabled = e.disabledCollectors or []; unit = cfg.config.systemd.units."'"$UNIT"'".text or ""; }'
FLAG_RE='--no-collector\.[a-zA-Z0-9_-]+|--collector\.[a-zA-Z0-9_-]+'

mapfile -t hosts < <(if [[ $# -gt 0 ]]; then printf '%s\n' "$@"; else nix eval --json .#nixosConfigurations --apply 'builtins.attrNames' | jq -r '.[]'; fi)

fail=0
for host in "${hosts[@]}"; do
  echo "== $host =="
  json="$(nix eval --json ".#nixosConfigurations.$host" --apply "$APPLY")" || { fail=1; continue; }

  dup_en="$(jq -r '.enabled[]' <<<"$json" | sort | uniq -d)"
  dup_dis="$(jq -r '.disabled[]' <<<"$json" | sort | uniq -d)"
  overlap="$(comm -12 <(jq -r '.enabled[]' <<<"$json" | sort -u) <(jq -r '.disabled[]' <<<"$json" | sort -u))"
  echo "  enabled=$(jq '.enabled|length' <<<"$json") disabled=$(jq '.disabled|length' <<<"$json")" \
       "dup_enabled=${dup_en:-none} dup_disabled=${dup_dis:-none} overlap=${overlap:-none}"
  [[ -z "$dup_en$dup_dis$overlap" ]] || fail=1

  unit_text="$(jq -r '.unit // ""' <<<"$json")"
  if [[ -z "$unit_text" ]]; then
    echo "  unit $UNIT not generated"; fail=1; continue
  fi
  dup_flags="$(grep -oE "$FLAG_RE" <<<"$unit_text" | sed -E 's/^--(no-)?collector\.//' | sort | uniq -d)"
  echo "  unit ExecStart flags=$(grep -oE "$FLAG_RE" <<<"$unit_text" | wc -l) repeated=${dup_flags:-none}"
  [[ -z "$dup_flags" ]] || fail=1
done

echo "RESULT: $([[ $fail -eq 0 ]] && echo PASS || echo FAIL)"
exit "$fail"
