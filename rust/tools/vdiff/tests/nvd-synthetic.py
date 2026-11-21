"""Write tests/fixtures/synthetic.json: nvd's tricky cases, rendered by nvd itself.

    python3 -I tests/nvd-synthetic.py "$(readlink -f "$(command -v nvd)")" tests/fixtures/synthetic.json

nvd's own code runs (its module is loaded, not its main), with the three
places it asks Nix (closure, references, closure size) answered from the
closures below, so the expected text is nvd's and needs no store.
"""

import json
import os
import sys
import tempfile
import types
from pathlib import Path

nvd_path, out_path = sys.argv[1], sys.argv[2]
nvd = types.ModuleType("nvd")
with open(nvd_path, encoding="utf-8") as f:
    exec(compile(f.read(), nvd_path, "exec"), nvd.__dict__)


def path(n, name):
    return f"{n:032d}-{name}"


# (hash number, name). A path both sides list with the same number is shared.
OLD = [
    (1, "hello-2.12.1"),
    (2, "openssl-3.0.13"), (3, "openssl-3.0.13-bin"), (4, "openssl-3.0.13-dev"),
    (5, "zlib-1.3.1"),
    (6, "glibc-2.40-66"), (7, "glibc-2.40-66-bin"),
    (8, "python3.12-requests-2.31.0"),
    (9, "linux-6.6.1"), (10, "linux-6.6.1-modules"),
    (11, "mixed-1.0"), (12, "mixed-3.0"),
    (13, "pre-1.0pre1"),
    (14, "zeros-007"),
    (15, "gone-forever-1.0"),
    (16, "gone-selected-2.0"),
    (17, "source"), (18, "source"),
    (19, "unit-dbus.service"),
    (20, "etc"),
    (21, "selected-later-4.2"),
    (22, "deselected-1.1"),
    (23, "1password-8.10.7"),
    (24, "x264-0-unstable-2023-10-01"),
    (25, "shrinks-1.0"), (26, "shrinks-1.0"), (27, "shrinks-1.0"),
    (28, "system-path"),
]
NEW = [
    (101, "hello-2.12.2"),
    (102, "openssl-3.0.13"), (3, "openssl-3.0.13-bin"), (104, "openssl-3.0.14-dev"),
    (5, "zlib-1.3.1"),
    (106, "glibc-2.40-36"), (107, "glibc-2.40-36-bin"),
    (108, "python3.12-requests-2.32.3"),
    (109, "linux-6.10"), (110, "linux-6.10-modules"),
    (111, "mixed-2.0"),
    (113, "pre-1.0"),
    (114, "zeros-7"),
    (117, "source"), (18, "source"), (118, "source"),
    (119, "unit-dbus.service"),
    (20, "etc"),
    (21, "selected-later-4.2"),
    (22, "deselected-1.1"),
    (123, "1password-8.10.9"),
    (24, "x264-0-unstable-2023-10-01"),
    (125, "shrinks-1.0"),
    (128, "system-path"),
] + [(200 + i, f"fresh{i:02d}-{i}.0") for i in range(11)] + [(300, "fresh-noversion")]

OLD_SELECTED = [n for n in OLD if n[1].split("-")[0] in ("hello", "openssl", "gone", "deselected", "1password", "linux")]
NEW_SELECTED = [n for n in NEW if n[1].split("-")[0] in ("hello", "openssl", "selected", "1password", "fresh03", "linux")]

SIZES = {"old": 7_340_032_000, "new": 7_402_946_560}


def store(entries):
    return ["/nix/store/" + path(n, name) for n, name in entries]


CLOSURES = {"old": store(OLD), "new": store(NEW)}
SELECTED = {"old": store(OLD_SELECTED), "new": store(NEW_SELECTED)}


def from_closure(p):
    return nvd.PackageSet.from_nix_query_result(CLOSURES[Path(p).name])


def from_direct_dependencies(p):
    return nvd.PackageSet.from_nix_query_result(SELECTED[Path(p).parent.name])


def from_nix_query_result(result_paths):
    packages = []
    for result_path in result_paths:
        pname, version = nvd.parse_pname_version(result_path)
        packages.append(nvd.Package(pname=pname, version=nvd.Version(version), store_path=nvd.StorePath(result_path)))
    return nvd.PackageSet(packages, result_paths)


nvd.PackageSet.from_nix_query_result = staticmethod(from_nix_query_result)
nvd.PackageSet.from_closure = staticmethod(from_closure)
nvd.PackageSet.from_direct_dependencies = staticmethod(from_direct_dependencies)
nvd.query_closure_disk_usage_bytes = lambda p: SIZES[Path(p).name]

with tempfile.TemporaryDirectory() as tmp:
    for side in ("old", "new"):
        os.makedirs(os.path.join(tmp, side, "sw"))
    cwd = os.getcwd()
    os.chdir(tmp)
    captured = []
    real_print = print
    nvd.__dict__["print"] = lambda *a, **k: captured.append(" ".join(str(x) for x in a) + "\n")
    try:
        nvd.run_diff(
            root1="old",
            root2="new",
            sort_comparator=nvd.PackageListEntryCombinedComparator.from_str(None),
            only_selected=False,
            version_highlight=nvd.VERSION_HIGHLIGHT_DEFAULT,
        )
    finally:
        os.chdir(cwd)


def base(entries):
    return [path(n, name) for n, name in entries]


old_paths, new_paths = set(base(OLD)), set(base(NEW))
doc = {
    "common": sorted(old_paths & new_paths),
    "old": {"label": "old", "root": "/nix/store/" + path(0, "old"), "only": sorted(old_paths - new_paths),
            "selected": sorted(base(OLD_SELECTED)), "narSize": SIZES["old"]},
    "new": {"label": "new", "root": "/nix/store/" + path(0, "new"), "only": sorted(new_paths - old_paths),
            "selected": sorted(base(NEW_SELECTED)), "narSize": SIZES["new"]},
    "nvd": "".join(captured),
}
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=1)
    f.write("\n")
real_print(doc["nvd"], end="")
