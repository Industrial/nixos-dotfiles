"""Subprocess environment policy for Cursor child runtimes."""

from __future__ import annotations

import os

from .credentials import resolve_background_api_key


SAFE_ENV_NAMES = {
    "APPDATA",
    "CI",
    "COLORTERM",
    "COMSPEC",
    "GITHUB_ACTIONS",
    "HOME",
    "HOMEDRIVE",
    "HOMEPATH",
    "LANG",
    "LOCALAPPDATA",
    "LOGNAME",
    "PATH",
    "PATHEXT",
    "PROGRAMDATA",
    "PROGRAMFILES",
    "PROGRAMFILES(X86)",
    "RUNNER_TEMP",
    "SHELL",
    "SYSTEMDRIVE",
    "SYSTEMROOT",
    "TEMP",
    "TERM",
    "TMP",
    "TMPDIR",
    "USER",
    "USERDOMAIN",
    "USERNAME",
    "USERPROFILE",
    "WINDIR",
    "__CF_USER_TEXT_ENCODING",
}
SAFE_ENV_PREFIXES = ("LC_", "XDG_")
TEST_ENV_PREFIXES = ("FAKE_", "EXPECT_")


def cursor_child_env(
    *,
    extra: dict[str, str] | None = None,
    include_cursor_credentials: bool = True,
    include_test_controls: bool = False,
) -> dict[str, str]:
    """Return a scoped environment for Cursor/SDK subprocesses.

    The parent Hermes process may contain provider, gateway, GitHub, or other
    unrelated tokens. Cursor children only receive OS/runtime basics, optional
    Cursor credentials, and explicit extras required by the harness.
    """

    env: dict[str, str] = {}
    for name, value in os.environ.items():
        if name.upper() in SAFE_ENV_NAMES or name.startswith(SAFE_ENV_PREFIXES):
            env[name] = value
        elif include_test_controls and name.startswith(TEST_ENV_PREFIXES):
            env[name] = value

    if include_cursor_credentials:
        key = resolve_background_api_key()
        if key:
            env["CURSOR_API_KEY"] = key
            env["CURSOR_BACKGROUND_API_KEY"] = key

    for name, value in (extra or {}).items():
        if value is not None:
            env[str(name)] = str(value)
    return env
