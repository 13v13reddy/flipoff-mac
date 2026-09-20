#!/usr/bin/env python3
"""Loopback JSON API for agent control of FlipOff."""

from __future__ import annotations

import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import urlparse

from flipoff_core import (
    advance_quote,
    clear_message,
    list_quotes,
    reset_state,
    set_message,
    set_settings,
    state_payload,
)


def _json_body(handler: BaseHTTPRequestHandler) -> dict[str, Any]:
    length = int(handler.headers.get("Content-Length", "0"))
    if length > 32_768:
        raise ValueError("request body is too large")
    raw = handler.rfile.read(length) if length else b"{}"
    value = json.loads(raw.decode("utf-8"))
    if not isinstance(value, dict):
        raise ValueError("request body must be a JSON object")
    return value


class FlipOffAPIHandler(BaseHTTPRequestHandler):
    server_version = "FlipOffAgentAPI/1.0"

    def log_message(self, format: str, *args: Any) -> None:
        print(f"[flipoff-api] {format % args}", file=sys.stderr)

    def _authorized(self) -> bool:
        expected = os.environ.get("FLIPOFF_API_TOKEN")
        if not expected:
            return True
        return self.headers.get("Authorization") == f"Bearer {expected}"

    def _send(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
        self.end_headers()
        self.wfile.write(body)

    def _error(self, status: int, message: str) -> None:
        self._send(status, {"error": message})

    def _guard(self) -> bool:
        if self._authorized():
            return True
        self._error(401, "missing or invalid bearer token")
        return False

    def do_OPTIONS(self) -> None:
        self._send(204, {})

    def do_GET(self) -> None:
        if not self._guard():
            return
        route = urlparse(self.path).path.rstrip("/") or "/"
        if route == "/v1/health":
            self._send(200, {"ok": True, "service": "flipoff", "version": "1.0"})
        elif route == "/v1/state":
            self._send(200, state_payload())
        elif route == "/v1/quotes":
            self._send(200, {"quotes": list_quotes()})
        else:
            self._error(404, "not found")

    def do_POST(self) -> None:
        if not self._guard():
            return
        route = urlparse(self.path).path.rstrip("/") or "/"
        try:
            body = _json_body(self)
            if route == "/v1/message":
                state = set_message(body.get("message", ""), body.get("author"))
            elif route == "/v1/advance":
                state = advance_quote()
            elif route == "/v1/settings":
                state = set_settings(
                    paused=body.get("paused"),
                    rotation_seconds=body.get("rotation_seconds"),
                    accent_hex=body.get("accent_hex"),
                )
            elif route == "/v1/reset":
                state = reset_state()
            else:
                self._error(404, "not found")
                return
            self._send(200, {"state": state, "effective_quote": state_payload()["effective_quote"]})
        except (TypeError, ValueError, json.JSONDecodeError) as error:
            self._error(400, str(error))

    def do_DELETE(self) -> None:
        if not self._guard():
            return
        route = urlparse(self.path).path.rstrip("/") or "/"
        if route != "/v1/message":
            self._error(404, "not found")
            return
        state = clear_message()
        self._send(200, {"state": state, "effective_quote": state_payload()["effective_quote"]})


def main() -> None:
    host = os.environ.get("FLIPOFF_API_HOST", "127.0.0.1")
    port = int(os.environ.get("FLIPOFF_API_PORT", "47831"))
    server = ThreadingHTTPServer((host, port), FlipOffAPIHandler)
    print(f"FlipOff API listening on http://{host}:{port}", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
