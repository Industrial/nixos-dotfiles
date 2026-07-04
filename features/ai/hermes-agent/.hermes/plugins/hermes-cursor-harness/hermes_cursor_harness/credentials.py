"""Credential helpers for Cursor Background Agents API keys."""

from __future__ import annotations

import os
import shutil
import subprocess
from dataclasses import dataclass
from typing import Any


BACKGROUND_KEY_ENV_NAMES = ("CURSOR_BACKGROUND_API_KEY", "CURSOR_API_KEY")
BACKGROUND_KEYCHAIN_SERVICE = "cursor-background-api-key"


class CredentialError(RuntimeError):
    """Raised when a credential operation cannot be completed."""


@dataclass(frozen=True)
class CredentialStatus:
    available: bool
    source: str
    fingerprint: str | None = None
    key: str | None = None

    def public(self) -> dict[str, Any]:
        return {"available": self.available, "source": self.source, "fingerprint": self.fingerprint}


def background_key_status(*, include_key: bool = False) -> CredentialStatus:
    for env_name in BACKGROUND_KEY_ENV_NAMES:
        value = os.environ.get(env_name)
        if value:
            return CredentialStatus(True, env_name, redact_secret(value), value if include_key else None)
    keychain = read_background_key_from_keychain()
    if keychain:
        return CredentialStatus(True, "macos-keychain", redact_secret(keychain), keychain if include_key else None)
    return CredentialStatus(False, "none")


def resolve_background_api_key() -> str | None:
    return background_key_status(include_key=True).key


def store_background_key_in_keychain(key: str, *, account: str | None = None) -> None:
    key = str(key or "").strip()
    if not key:
        raise CredentialError("Cursor Background Agents API key is required")
    if not _security_available():
        raise CredentialError("macOS security command is not available")
    proc = subprocess.run(
        [
            "security",
            "add-generic-password",
            "-a",
            account or _default_account(),
            "-s",
            BACKGROUND_KEYCHAIN_SERVICE,
            "-w",
            key,
            "-U",
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise CredentialError(proc.stderr.strip() or "failed to store key in macOS Keychain")


def read_background_key_from_keychain(*, account: str | None = None) -> str | None:
    if not _security_available():
        return None
    command = [
        "security",
        "find-generic-password",
        "-s",
        BACKGROUND_KEYCHAIN_SERVICE,
        "-w",
    ]
    if account:
        command[2:2] = ["-a", account]
    proc = subprocess.run(
        command,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        return None
    key = proc.stdout.strip()
    return key or None


def delete_background_key_from_keychain(*, account: str | None = None) -> bool:
    if not _security_available():
        return False
    command = ["security", "delete-generic-password", "-s", BACKGROUND_KEYCHAIN_SERVICE]
    if account:
        command.extend(["-a", account])
    proc = subprocess.run(
        command,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    return proc.returncode == 0


def redact_secret(value: str) -> str:
    value = str(value or "")
    if not value:
        return ""
    if len(value) <= 8:
        return "*" * len(value)
    return f"{value[:4]}...{value[-4:]}"


def _security_available() -> bool:
    return bool(shutil.which("security"))


def _default_account() -> str:
    return os.environ.get("USER") or "default"
