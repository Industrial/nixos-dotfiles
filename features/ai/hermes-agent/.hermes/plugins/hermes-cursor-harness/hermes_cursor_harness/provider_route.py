"""Provider-route validation and install planning for Hermes core."""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path
from typing import Any


EXPECTED_MARKERS = {
    "agent/cursor_harness_adapter.py": ["CURSOR_HARNESS_PROVIDER", "run_cursor_harness_provider_turn"],
    "hermes_cli/runtime_provider.py": ["cursor_harness", "cursor-harness"],
    "hermes_cli/models.py": ["cursor/default", "cursor-harness"],
    "hermes_cli/auth.py": ["get_cursor_harness_status", "cursor-harness"],
    "hermes_cli/providers.py": ["cursor-harness"],
    "run_agent.py": ["_run_cursor_harness_conversation", "cursor_harness"],
}

PATCH_PATHS = list(EXPECTED_MARKERS)


def validate_provider_route(hermes_root: str | Path) -> dict[str, Any]:
    root = Path(hermes_root).expanduser().resolve()
    checks = []
    for rel, markers in EXPECTED_MARKERS.items():
        path = root / rel
        if not path.exists():
            checks.append({"path": rel, "status": "missing", "markers": markers})
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        missing = [marker for marker in markers if marker not in text]
        checks.append({"path": rel, "status": "pass" if not missing else "incomplete", "missing_markers": missing})
    success = all(item["status"] == "pass" for item in checks)
    return {"success": success, "hermes_root": str(root), "checks": checks, "missing": [item for item in checks if item["status"] != "pass"]}


def write_provider_route_bundle(
    *,
    hermes_root: str | Path | None,
    output_dir: str | Path,
) -> dict[str, Any]:
    target = Path(output_dir).expanduser().resolve()
    target.mkdir(parents=True, exist_ok=True)
    validation = validate_provider_route(hermes_root) if hermes_root else None
    manifest = {
        "name": "hermes-cursor-harness-provider-route",
        "description": "Checklist for upstreaming native cursor/* provider support into Hermes core.",
        "hermes_root": str(Path(hermes_root).expanduser().resolve()) if hermes_root else None,
        "validation": validation,
        "expected_markers": EXPECTED_MARKERS,
        "required_changes": [
            "Add agent/cursor_harness_adapter.py to render Hermes messages and invoke the SDK-first external harness package.",
            "Teach hermes_cli/runtime_provider.py to resolve provider=cursor-harness and model ids starting with cursor/.",
            "Add cursor-harness provider identity and auth status in hermes_cli/auth.py and hermes_cli/providers.py.",
            "Add Cursor SDK model discovery and cursor/default model ids in hermes_cli/models.py.",
            "Add AIAgent cursor_harness execution branch in run_agent.py that preserves Hermes session ownership.",
            "Add provider-route tests equivalent to tests/test_cursor_harness_provider.py.",
        ],
    }
    manifest_path = target / "provider-route-manifest.json"
    readme_path = target / "README.md"
    patch_path = _write_git_patch(hermes_root=hermes_root, output_dir=target) if hermes_root else None
    if patch_path:
        manifest["patch"] = str(patch_path)
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    readme_path.write_text(_bundle_readme(manifest), encoding="utf-8")
    files = [str(manifest_path), str(readme_path)]
    if patch_path:
        files.append(str(patch_path))
    return {"success": True, "bundle_dir": str(target), "files": files, "validation": validation}


def _bundle_readme(manifest: dict[str, Any]) -> str:
    lines = [
        "# Hermes Cursor Harness Provider Route",
        "",
        "This bundle is an upstreaming/install checklist for native `cursor/*` provider support.",
        "The public plugin remains the implementation package; Hermes core supplies the provider route.",
        "",
        "## Required Changes",
        "",
    ]
    for item in manifest["required_changes"]:
        lines.append(f"- {item}")
    lines.extend(
        [
            "",
            "## Validation",
            "",
            "Run:",
            "",
            "```bash",
            "python -m pytest -q -o addopts='' tests/test_cursor_harness_provider.py",
            "```",
            "",
        ]
    )
    if manifest.get("patch"):
        lines.extend(
            [
                "## Patch",
                "",
                "This bundle includes `cursor-provider-route.patch` from the supplied Hermes checkout.",
                "Review it against current upstream before applying.",
                "",
            ]
        )
    return "\n".join(lines)


def _write_git_patch(*, hermes_root: str | Path | None, output_dir: Path) -> Path | None:
    if not hermes_root or not shutil.which("git"):
        return None
    root = Path(hermes_root).expanduser().resolve()
    if not (root / ".git").exists():
        return None
    chunks: list[str] = []
    tracked = subprocess.run(
        ["git", "-C", str(root), "diff", "--", *PATCH_PATHS],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if tracked.stdout.strip():
        chunks.append(tracked.stdout)
    untracked = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--others", "--exclude-standard", "--", *PATCH_PATHS],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    for rel in [line.strip() for line in untracked.stdout.splitlines() if line.strip()]:
        diff = subprocess.run(
            ["git", "-C", str(root), "diff", "--no-index", "--", "/dev/null", rel],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if diff.stdout.strip():
            chunks.append(diff.stdout)
    if not chunks:
        return None
    patch_path = output_dir / "cursor-provider-route.patch"
    patch_path.write_text("\n".join(chunk.rstrip() for chunk in chunks) + "\n", encoding="utf-8")
    return patch_path
