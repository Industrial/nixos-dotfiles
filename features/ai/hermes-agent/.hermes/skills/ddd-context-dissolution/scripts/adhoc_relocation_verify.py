"""Ad-hoc relocation verification — COPY, edit the CONFIG block, run, DELETE.

Use when a move/rename is committed but foreign mid-flight WIP blocks claiming
full-suite green. Verifies the delivered behavior directly instead:
  1. old flat homes absent, destination package complete (modules + tests + __init__)
  2. every module imports under the project venv
  3. zero stale references tree-wide (dotted paths, space-form imports, bare class name)
  4. scoped pytest battery over suites that exercise the moved/renamed code
Prints an explicit AD-HOC VERDICT and exits nonzero on any FAIL. Report results
as AD-HOC evidence, never as "suite green". Delete the copy after running.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

# ----------------------------- CONFIG (edit these) -------------------------
REPO = Path("/data/Code/rust/solana-yield-optimizer")
PY = REPO / "python"  # pytest working directory
VENV_PY = REPO / ".devenv/state/venv/bin/python"
PKG_REL = "andromeda/services/freqai"  # destination package, repo-relative to PY
OLD_FLAT_MODULES = [  # pre-move flat names (existence check)
    "freqai_host", "freqai_pipeline", "freqai_lifecycle", "freqai_retrain",
    "freqai_adaptive", "freqai_walkforward", "freqai_sequence", "freqai_operator",
]
NEW_MODULES = [  # destination names inside the package
    "host_service", "pipeline", "lifecycle", "retrain",
    "adaptive", "walkforward", "sequence", "operator",
]
OLD_DOTTED_TOKENS = [f"andromeda.services.{m}" for m in OLD_FLAT_MODULES]
EXTRA_STALE_SUBSTRINGS = [  # sweep blind spots, e.g. space-form imports
    "from andromeda.services import freqai_",
]
BARE_CLASS_PATTERN = r"\bFreqAIHost\b(?!Service)"  # "" skips the rename scan
SCOPED_TARGETS = [  # pytest paths relative to PY
    *(f"andromeda/services/freqai/{m}_test.py" for m in NEW_MODULES),
]
# ---------------------------------------------------------------------------


def main() -> int:
    pkg = PY / PKG_REL
    parent = pkg.parent
    fails: list[str] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f"  [{detail}]" if detail else ""))
        if not ok:
            fails.append(name)

    head = subprocess.run(["git", "log", "--oneline", "-1"], capture_output=True,
                          text=True, cwd=REPO).stdout.strip()
    print("HEAD:", head)

    check(
        "old flat modules absent",
        not any((parent / f"{m}.py").exists() for m in OLD_FLAT_MODULES),
    )
    check(
        "package complete (modules + tests + __init__)",
        (pkg / "__init__.py").is_file()
        and all((pkg / f"{m}.py").is_file() for m in NEW_MODULES)
        and all((pkg / f"{m}_test.py").is_file() for m in NEW_MODULES),
    )

    env = {**os.environ, "QUESTDB_PG_URL": "unused://"}
    fqpn = "andromeda." + PKG_REL.replace("/", ".")
    mods = sorted({fqpn} | {f"{fqpn}.{m}" for m in NEW_MODULES})
    probe = f"import importlib\nfor m in {mods!r}: importlib.import_module(m)\nprint('ok')\n"
    r = subprocess.run([str(VENV_PY), "-c", probe], capture_output=True, text=True,
                       env=env, cwd=PY, timeout=180)
    check("all modules import under venv", r.returncode == 0,
          r.stdout.strip() or r.stderr.strip()[-140:])

    bare = re.compile(BARE_CLASS_PATTERN) if BARE_CLASS_PATTERN else None
    stale: list[str] = []
    for root in (PY / "andromeda", PY / "afml"):
        for p in root.rglob("*.py"):
            if "__pycache__" in p.parts:
                continue
            t = p.read_text(encoding="utf-8", errors="ignore")
            if (any(tok in t for tok in OLD_DOTTED_TOKENS)
                    or any(s in t for s in EXTRA_STALE_SUBSTRINGS)
                    or (bare and bare.search(t))):
                stale.append(p.name)
    check("zero stale references", not stale, ",".join(stale[:4]))

    r = subprocess.run([str(VENV_PY), "-m", "pytest", *SCOPED_TARGETS,
                        "-q", "--no-header"],
                       capture_output=True, text=True, env=env, cwd=PY, timeout=420)
    lines = r.stdout.strip().splitlines()
    summary = next((l for l in reversed(lines) if "passed" in l or "failed" in l), "?")
    check(f"scoped pytest green ({len(SCOPED_TARGETS)} targets)",
          r.returncode == 0, summary[-100:])

    print("\nAD-HOC VERDICT:", "PASS" if not fails else f"FAIL {fails}")
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
