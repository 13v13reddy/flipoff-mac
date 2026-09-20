# FlipOff agent control

FlipOff exposes the same local state through a loopback JSON API and an MCP stdio server. Both are dependency-free Python 3 scripts, so an agent can use the MCP tools without a package install.

## JSON API

Start the API from the repository root:

```bash
python3 agent/flipoff_api.py
```

It listens on `127.0.0.1:47831` by default. The API is intentionally loopback-only; set `FLIPOFF_API_TOKEN` if another local process should authenticate with a bearer token.

```bash
curl http://127.0.0.1:47831/v1/state
curl -X POST http://127.0.0.1:47831/v1/message \
  -H 'Content-Type: application/json' \
  -d '{"message":"SHIP IT","author":"YOUR AGENT"}'
curl -X POST http://127.0.0.1:47831/v1/settings \
  -H 'Content-Type: application/json' \
  -d '{"paused":false,"accent_hex":"00AAFF"}'
curl -X DELETE http://127.0.0.1:47831/v1/message
```

Routes:

- `GET /v1/health`
- `GET /v1/state`
- `GET /v1/quotes`
- `POST /v1/message` with `message` and optional `author`
- `POST /v1/advance`
- `POST /v1/settings` with `paused`, `rotation_seconds`, and/or `accent_hex`
- `POST /v1/reset`
- `DELETE /v1/message`

## MCP

Register `agent/flipoff_mcp.py` as a local stdio MCP server in the agent host:

```json
{
  "mcpServers": {
    "flipoff": {
      "command": "python3",
      "args": ["/absolute/path/to/flipoff/agent/flipoff_mcp.py"]
    }
  }
}
```

The MCP server exposes `flipoff_get_state`, `flipoff_set_message`, `flipoff_advance_quote`, `flipoff_clear_message`, `flipoff_set_settings`, and `flipoff_list_quotes`. It also exposes `flipoff://state` and `flipoff://quotes` resources.

The MCP process and the HTTP API write the same atomic JSON state file. On macOS the preferred path is the `group.com.flipoff.shared` container when present; otherwise it falls back to `~/Library/Application Support/FlipOff/agent-state.json`. Set `FLIPOFF_STATE_FILE` to force a path in development or CI.
