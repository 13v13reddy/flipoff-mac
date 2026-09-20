#!/usr/bin/env python3
"""Shared state and quote operations for the FlipOff API and MCP server."""

from __future__ import annotations

import contextlib
import copy
import datetime as dt
import fcntl
import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Iterator


QUOTES = [
    {"id": 0, "lines": ["", "GOD IS IN", "THE DETAILS .", "- LUDWIG MIES", ""]},
    {"id": 1, "lines": ["", "STAY HUNGRY", "STAY FOOLISH", "- STEVE JOBS", ""]},
    {"id": 2, "lines": ["", "GOOD DESIGN IS", "GOOD BUSINESS", "- THOMAS WATSON", ""]},
    {"id": 3, "lines": ["", "LESS IS MORE", "", "- MIES VAN DER ROHE", ""]},
    {"id": 4, "lines": ["", "MAKE IT SIMPLE", "BUT SIGNIFICANT", "- DON DRAPER", ""]},
    {"id": 5, "lines": ["", "HAVE NO FEAR OF", "PERFECTION", "- SALVADOR DALI", ""]},
]

DEFAULT_ACCENT = "00FF7F"
DEFAULT_ROTATION_SECONDS = 4.0
STATE_FILENAME = "agent-state.json"
APP_GROUP = "group.com.flipoff.shared"


def _standard_state_path() -> Path:
    return Path.home() / "Library" / "Application Support" / "FlipOff" / STATE_FILENAME


def _group_state_path() -> Path:
    return Path.home() / "Library" / "Group Containers" / APP_GROUP / STATE_FILENAME


def state_path() -> Path:
    override = os.environ.get("FLIPOFF_STATE_FILE")
    if override:
        return Path(override).expanduser()

    group_path = _group_state_path()
    if group_path.parent.exists():
        return group_path
    return _standard_state_path()


def _default_state() -> dict[str, Any]:
    return {
        "message": None,
        "author": None,
        "paused": False,
        "rotation_seconds": DEFAULT_ROTATION_SECONDS,
        "accent_hex": DEFAULT_ACCENT,
        "quote_index": 4,
        "updated_at": None,
        "source": "default",
    }


def _clean_hex(value: Any) -> str:
    candidate = str(value or DEFAULT_ACCENT).strip().lstrip("#").upper()
    if len(candidate) != 6 or any(char not in "0123456789ABCDEF" for char in candidate):
        raise ValueError("accent_hex must be a six-digit hex color")
    return candidate


def normalize_state(raw: dict[str, Any] | None) -> dict[str, Any]:
    state = _default_state()
    if isinstance(raw, dict):
        state.update(raw)

    message = state.get("message")
    state["message"] = str(message) if message is not None and str(message).strip() else None
    author = state.get("author")
    state["author"] = str(author).strip() if author is not None and str(author).strip() else None
    state["paused"] = bool(state.get("paused", False))
    state["rotation_seconds"] = max(2.0, min(86_400.0, float(state.get("rotation_seconds", DEFAULT_ROTATION_SECONDS))))
    state["accent_hex"] = _clean_hex(state.get("accent_hex", DEFAULT_ACCENT))
    state["quote_index"] = int(state.get("quote_index", 4)) % len(QUOTES)
    state["updated_at"] = state.get("updated_at")
    state["source"] = state.get("source") or "default"
    return state


@contextlib.contextmanager
def _lock(path: Path) -> Iterator[None]:
    lock_path = path.with_suffix(path.suffix + ".lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a+") as handle:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def load_state() -> dict[str, Any]:
    path = state_path()
    try:
        with path.open("r", encoding="utf-8") as handle:
            return normalize_state(json.load(handle))
    except FileNotFoundError:
        return normalize_state(None)
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        return normalize_state(None)


def _write_state_unlocked(path: Path, state: dict[str, Any]) -> dict[str, Any]:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(state, indent=2, sort_keys=True) + "\n"
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_path, path)
    finally:
        temporary_path.unlink(missing_ok=True)
    return state


def save_state(changes: dict[str, Any]) -> dict[str, Any]:
    path = state_path()
    with _lock(path):
        state = load_state()
        state.update(changes)
        state["updated_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
        state["source"] = "agent"
        state = normalize_state(state)
        result = _write_state_unlocked(path, state)
    notify_native()
    return result


def reset_state() -> dict[str, Any]:
    path = state_path()
    with _lock(path):
        state = _default_state()
        state["updated_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
        state["source"] = "agent"
        result = _write_state_unlocked(path, state)
    notify_native()
    return result


def effective_quote(state: dict[str, Any] | None = None) -> dict[str, Any]:
    state = normalize_state(state or load_state())
    if state["message"]:
        lines = state["message"].replace("\r\n", "\n").split("\n")[:5]
        if state["author"]:
            lines.append(f"- {state['author'].lstrip('- ').strip()}")
        lines = (lines + [""] * 5)[:5]
        return {"id": -1, "lines": lines, "source": "agent"}

    quote = copy.deepcopy(QUOTES[state["quote_index"]])
    quote["source"] = "library"
    return quote


def state_payload() -> dict[str, Any]:
    state = load_state()
    return {
        **state,
        "effective_quote": effective_quote(state),
        "state_file": str(state_path()),
    }


def list_quotes() -> list[dict[str, Any]]:
    return copy.deepcopy(QUOTES)


def set_message(message: str, author: str | None = None) -> dict[str, Any]:
    if not isinstance(message, str) or not message.strip():
        raise ValueError("message must be a non-empty string")
    if len(message) > 500:
        raise ValueError("message must be 500 characters or fewer")
    return save_state({"message": message.strip(), "author": author})


def clear_message() -> dict[str, Any]:
    return save_state({"message": None, "author": None})


def advance_quote() -> dict[str, Any]:
    state = load_state()
    next_index = (int(state.get("quote_index", 4)) + 1) % len(QUOTES)
    quote = QUOTES[next_index]
    lines = [line for line in quote["lines"] if line]
    author = lines[-1].lstrip("- ").strip() if lines and lines[-1].startswith("-") else None
    message_lines = lines[:-1] if author else lines
    return save_state(
        {
            "message": "\n".join(message_lines),
            "author": author,
            "quote_index": next_index,
        }
    )


def set_settings(
    *, paused: bool | None = None, rotation_seconds: float | None = None, accent_hex: str | None = None
) -> dict[str, Any]:
    changes: dict[str, Any] = {}
    if paused is not None:
        changes["paused"] = bool(paused)
    if rotation_seconds is not None:
        changes["rotation_seconds"] = rotation_seconds
    if accent_hex is not None:
        changes["accent_hex"] = accent_hex
    if not changes:
        raise ValueError("provide at least one setting")
    return save_state(changes)


def notify_native() -> None:
    if os.sys.platform != "darwin" or os.environ.get("FLIPOFF_DISABLE_APP_NOTIFY") == "1":
        return
    try:
        subprocess.run(
            ["open", "-g", "flipoff://refresh"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        pass
