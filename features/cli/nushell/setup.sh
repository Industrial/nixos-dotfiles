#!/usr/bin/env bash
# Back-compat wrapper — prefer bin/link-files-nixos (also run from bin/update/system).
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
exec features/cli/nushell/bin/link-files-nixos
