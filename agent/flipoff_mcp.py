#!/usr/bin/env python3
"""Dependency-free MCP stdio server for FlipOff agent control."""

from __future__ import annotations

import json
import sys
from typing import Any

from flipoff_core import (
    advance_quote,
    clear_message,
    list_quotes,
    reset_state,
    set_message,
    set_settings,
    state_payload,
)


SERVER_INFO = {"name": "flipoff", "version": "1.0.0"}
TOOLS = [
    {
        "name": "flipoff_get_state",
        "description": "Read the current FlipOff quote, display settings, and shared state path.",
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "flipoff_set_message",
        "description": "Set the message shown by the FlipOff widget and screen saver. Newlines create board rows.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "message": {"type": "string", "description": "One to five display rows."},
                "author": {"type": "string", "description": "Optional attribution without the leading dash."},
            },
            "required": ["message"],
            "additionalProperties": False,
        },
    },
    {
        "name": "flipoff_advance_quote",
        "description": "Advance to the next built-in quote and show it immediately.",
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "flipoff_clear_message",
        "description": "Clear the agent override and return to the built-in rotating quote library.",
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "flipoff_set_settings",
        "description": "Update pause state, quote rotation speed, or the accent color.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "paused": {"type": "boolean"},
                "rotation_seconds": {"type": "number", "minimum": 2, "maximum": 86400},
                "accent_hex": {"type": "string", "pattern": "^[#]?[0-9a-fA-F]{6}$"},
            },
            "additionalProperties": False,
        },
    },
    {
        "name": "flipoff_list_quotes",
        "description": "List the built-in quote library available to FlipOff.",
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
]


def result(value: Any, *, is_error: bool = False) -> dict[str, Any]:
    payload = {"content": [{"type": "text", "text": json.dumps(value, indent=2)}], "isError": is_error}
    if not is_error and isinstance(value, dict):
        payload["structuredContent"] = value
    return payload


def dispatch_tool(name: str, arguments: dict[str, Any]) -> dict[str, Any]:
    if name == "flipoff_get_state":
        return state_payload()
    if name == "flipoff_set_message":
        return {"state": set_message(arguments.get("message", ""), arguments.get("author")), "effective_quote": state_payload()["effective_quote"]}
    if name == "flipoff_advance_quote":
        return {"state": advance_quote(), "effective_quote": state_payload()["effective_quote"]}
    if name == "flipoff_clear_message":
        return {"state": clear_message(), "effective_quote": state_payload()["effective_quote"]}
    if name == "flipoff_set_settings":
        return {
            "state": set_settings(
                paused=arguments.get("paused"),
                rotation_seconds=arguments.get("rotation_seconds"),
                accent_hex=arguments.get("accent_hex"),
            ),
            "effective_quote": state_payload()["effective_quote"],
        }
    if name == "flipoff_list_quotes":
        return {"quotes": list_quotes()}
    raise ValueError(f"unknown tool: {name}")


def handle(request: dict[str, Any]) -> dict[str, Any] | None:
    method = request.get("method")
    request_id = request.get("id")

    if method in {"notifications/initialized", "notifications/cancelled"}:
        return None

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": {
                "protocolVersion": request.get("params", {}).get("protocolVersion", "2024-11-05"),
                "capabilities": {
                    "tools": {"listChanged": False},
                    "resources": {"subscribe": False, "listChanged": False},
                },
                "serverInfo": SERVER_INFO,
            },
        }

    if method == "server/discover":
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": {
                "serverInfo": SERVER_INFO,
                "protocolVersions": ["2026-07-28", "2025-11-25", "2024-11-05"],
                "capabilities": {"tools": {}, "resources": {}},
            },
        }

    if method == "tools/list":
        return {"jsonrpc": "2.0", "id": request_id, "result": {"tools": TOOLS}}

    if method == "resources/list":
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": {
                "resources": [
                    {"uri": "flipoff://state", "name": "Current FlipOff state", "mimeType": "application/json"},
                    {"uri": "flipoff://quotes", "name": "Built-in FlipOff quotes", "mimeType": "application/json"},
                ]
            },
        }

    if method == "resources/read":
        uri = request.get("params", {}).get("uri")
        if uri == "flipoff://state":
            value = state_payload()
        elif uri == "flipoff://quotes":
            value = {"quotes": list_quotes()}
        else:
            return {"jsonrpc": "2.0", "id": request_id, "error": {"code": -32002, "message": "resource not found"}}
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": {"contents": [{"uri": uri, "mimeType": "application/json", "text": json.dumps(value, indent=2)}]},
        }

    if method == "tools/call":
        params = request.get("params", {})
        try:
            value = dispatch_tool(params.get("name", ""), params.get("arguments") or {})
            return {"jsonrpc": "2.0", "id": request_id, "result": result(value)}
        except (TypeError, ValueError, KeyError) as error:
            return {"jsonrpc": "2.0", "id": request_id, "result": result({"error": str(error)}, is_error=True)}

    if request_id is not None:
        return {"jsonrpc": "2.0", "id": request_id, "error": {"code": -32601, "message": f"method not found: {method}"}}
    return None


def main() -> None:
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            request = json.loads(line)
            response = handle(request)
            if response is not None:
                sys.stdout.write(json.dumps(response, separators=(",", ":")) + "\n")
                sys.stdout.flush()
        except json.JSONDecodeError as error:
            response = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": str(error)}}
            sys.stdout.write(json.dumps(response) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
